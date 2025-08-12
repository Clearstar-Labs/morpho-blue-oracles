// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

// IERC20 interface for token operations
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Morpho Blue interface
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

// Oracle interface to get current price
interface IOracle {
    function price() external view returns (uint256);
}

contract BorrowMorphoLoanToken is Script {
    
    function getBorrowAmount() internal view returns (uint256) {
        try vm.envUint("BORROW_AMOUNT") returns (uint256 amount) {
            return amount;
        } catch {
            revert("BORROW_AMOUNT environment variable not set");
        }
    }

    function getMarketParams() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: vm.envAddress("LOAN_TOKEN"),
            collateralToken: vm.envAddress("COLLATERAL_TOKEN"),
            oracle: vm.envAddress("ORACLE_ADDRESS"),
            irm: vm.envAddress("IRM_ADDRESS"),
            lltv: vm.envUint("LLTV")
        });
    }

    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
    
    function calculateMaxBorrow(uint256 collateralAmount, uint256 oraclePrice, uint256 lltv) internal pure returns (uint256) {
        // Oracle price is scaled by 1e36, collateral has 18 decimals, loan token decimals vary
        // collateralValue = collateralAmount * oraclePrice / 1e36 (in loan token terms)
        // maxBorrow = collateralValue * lltv / 1e18
        return (collateralAmount * oraclePrice * lltv) / (1e36 * 1e18);
    }
    
    function run() external {
        // Get all required addresses from environment variables
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");

        // Get user address
        address user = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Get borrow amount
        uint256 borrowAmount = getBorrowAmount();

        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        // Get token info for display
        IERC20 loanToken = IERC20(marketParams.loanToken);
        IERC20 collateralToken = IERC20(marketParams.collateralToken);

        string memory loanTokenSymbol;
        string memory collateralTokenSymbol;

        try loanToken.symbol() returns (string memory symbol) {
            loanTokenSymbol = symbol;
        } catch {
            loanTokenSymbol = "LOAN_TOKEN";
        }

        try collateralToken.symbol() returns (string memory symbol) {
            collateralTokenSymbol = symbol;
        } catch {
            collateralTokenSymbol = "COLLATERAL_TOKEN";
        }

        console2.log("=== Borrowing Loan Token from Morpho Market ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Morpho contract:", morphoContract);
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("Loan token:", marketParams.loanToken);
        console2.log("Loan token symbol:", loanTokenSymbol);
        console2.log("Collateral token:", marketParams.collateralToken);
        console2.log("Collateral token symbol:", collateralTokenSymbol);
        console2.log("User address:", user);
        console2.log("Borrow amount:", borrowAmount);

        // Check current position
        IMorpho morpho = IMorpho(morphoContract);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);

        console2.log("\n=== Current Position ===");
        console2.log("Supply shares:", supplySharesBefore);
        console2.log("Borrow shares:", borrowSharesBefore);
        console2.log("Collateral:", collateralBefore);

        // Check if user has collateral
        require(collateralBefore > 0, string(abi.encodePacked("No collateral found. Supply ", collateralTokenSymbol, " collateral first")));
        
        // Get current oracle price
        IOracle oracle = IOracle(marketParams.oracle);
        uint256 currentPrice;
        try oracle.price() returns (uint256 price) {
            currentPrice = price;
            console2.log("Current oracle price (scaled by 1e36):", currentPrice);
        } catch {
            console2.log("Warning: Could not fetch oracle price");
            currentPrice = 1e36; // Fallback to 1:1 ratio
        }

        // Calculate maximum borrowable amount
        uint256 lltv = marketParams.lltv;
        uint256 maxBorrowable = calculateMaxBorrow(collateralBefore, currentPrice, lltv);
        console2.log("Maximum borrowable", loanTokenSymbol, ":", maxBorrowable);
        console2.log("Requested borrow amount:", borrowAmount);

        // Safety check
        uint256 lltvPercent = (lltv * 100) / 1e18;
        require(borrowAmount <= maxBorrowable, string(abi.encodePacked("Borrow amount exceeds maximum borrowable (", vm.toString(lltvPercent), "% LTV)")));

        // Calculate health factor after borrow
        uint256 healthFactorAfter = (maxBorrowable * 1e18) / borrowAmount;
        console2.log("Health factor after borrow (1e18 = 100%):", healthFactorAfter);

        if (healthFactorAfter < 1.1e18) {
            console.log("WARNING: Health factor will be below 110% - risky position!");
        }

        // Check loan token balance before borrow
        uint256 loanTokenBalanceBefore = loanToken.balanceOf(user);
        console2.log(loanTokenSymbol, "balance before borrow:", loanTokenBalanceBefore);
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        // Borrow loan token (using 0 for shares means we want to borrow exact assets)
        console2.log("\n=== Borrowing", loanTokenSymbol, "===");
        try morpho.borrow(marketParams, borrowAmount, 0, user, user) returns (uint256 assetsBorrowed, uint256 sharesBorrowed) {
            console2.log(loanTokenSymbol, "borrowed successfully!");
            console2.log("Assets borrowed:", assetsBorrowed);
            console2.log("Shares borrowed:", sharesBorrowed);
        } catch Error(string memory reason) {
            console2.log("Borrow failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Borrow failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Borrow failed");
        }

        // Check position after borrow
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) = morpho.position(marketId, user);

        console2.log("\n=== Position After Borrow ===");
        console2.log("Supply shares:", supplySharesAfter);
        console2.log("Borrow shares:", borrowSharesAfter);
        console2.log("Collateral:", collateralAfter);

        // Check loan token balance after borrow
        uint256 loanTokenBalanceAfter = loanToken.balanceOf(user);
        console2.log(loanTokenSymbol, "balance after borrow:", loanTokenBalanceAfter);

        console2.log("\n=== Borrow Summary ===");
        console2.log("Borrow shares added:", borrowSharesAfter - borrowSharesBefore);
        console2.log("Total borrow shares:", borrowSharesAfter);
        console2.log(loanTokenSymbol, "received:", loanTokenBalanceAfter - loanTokenBalanceBefore);
        console2.log("Collateral used:", collateralBefore);

        vm.stopBroadcast();

        console2.log("\n=== Important Notes ===");
        console2.log("1. You now owe", loanTokenSymbol, "that accrues interest over time");
        console2.log("2. Monitor your position health factor regularly");
        console2.log("3. If health factor drops below 100%, you risk liquidation");
        console2.log("4. Consider repaying or adding collateral if price moves against you");
        console2.log("5. Use repay scripts to repay the loan");
        console2.log("6. Market ID for reference:", vm.toString(marketId));

        console2.log("\n=== Risk Management ===");
        console2.log("Current LTV:", (borrowAmount * 1e18) / maxBorrowable, "/ 1e18");
        console2.log("Liquidation threshold:", lltvPercent, "%");
        console2.log("Recommended: Keep LTV below", (lltvPercent - 10), "% for safety buffer");
    }
}
