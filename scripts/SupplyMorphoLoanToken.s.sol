// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

// IERC20 interface for token operations
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
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

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesReturned);

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

contract SupplyMorphoLoanToken is Script {
    
    function getSupplyAmount(address user, address loanToken) internal view returns (uint256) {
        try vm.envUint("SUPPLY_AMOUNT") returns (uint256 amount) {
            return amount;
        } catch {
            // Use full balance if no amount specified
            IERC20 token = IERC20(loanToken);
            return token.balanceOf(user);
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
    
    function run() external {
        // Get all required addresses from environment variables
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");

        // Get user address
        address user = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        // Get supply amount (may depend on user's balance)
        uint256 supplyAmount = getSupplyAmount(user, marketParams.loanToken);

        // Get token info for display
        IERC20 loanToken = IERC20(marketParams.loanToken);
        string memory tokenSymbol;
        try loanToken.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "TOKEN";
        }

        console.log("=== Supplying Loan Token to Morpho Market ===");
        console.log("Chain ID:", block.chainid);
        console.log("Morpho contract:", morphoContract);
        console.log("Market ID:", vm.toString(marketId));
        console.log("Loan token:", marketParams.loanToken);
        console.log("Token symbol:", tokenSymbol);
        console.log("User address:", user);
        console.log("Supply amount:", supplyAmount);

        // Check loan token balance
        uint256 balance = loanToken.balanceOf(user);
        console.log("Token balance:", balance);

        require(balance >= supplyAmount, "Insufficient token balance");

        // Check current allowance
        uint256 currentAllowance = loanToken.allowance(user, morphoContract);
        console.log("Current allowance:", currentAllowance);

        vm.startBroadcast();

        // Approve if needed
        if (currentAllowance < supplyAmount) {
            console.log("Approving token spend...");
            bool success = loanToken.approve(morphoContract, supplyAmount);
            require(success, "Approval failed");
            console.log("Approval successful");
        } else {
            console.log("Sufficient allowance already exists");
        }

        // Check position before supply
        IMorpho morpho = IMorpho(morphoContract);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);
        
        console.log("\n=== Position Before Supply ===");
        console.log("Supply shares:", supplySharesBefore);
        console.log("Borrow shares:", borrowSharesBefore);
        console.log("Collateral:", collateralBefore);
        
        // Supply loan token (using 0 for shares means we want to supply exact assets)
        console.log("\n=== Supplying Loan Token ===");
        try morpho.supply(marketParams, supplyAmount, 0, user, "") returns (uint256 assetsSupplied, uint256 sharesReturned) {
            console.log("Loan token supplied successfully!");
            console.log("Assets supplied:", assetsSupplied);
            console.log("Shares returned:", sharesReturned);
        } catch Error(string memory reason) {
            console.log("Supply failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Supply failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Supply failed");
        }

        // Check position after supply
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) = morpho.position(marketId, user);

        console.log("\n=== Position After Supply ===");
        console.log("Supply shares:", supplySharesAfter);
        console.log("Borrow shares:", borrowSharesAfter);
        console.log("Collateral:", collateralAfter);

        console.log("\n=== Supply Summary ===");
        console.log("Supply shares added:", supplySharesAfter - supplySharesBefore);
        console.log("Total supply shares:", supplySharesAfter);
        console.log(tokenSymbol, "supplied to market for borrowers");

        vm.stopBroadcast();

        // Get collateral token info for display
        IERC20 collateralToken = IERC20(marketParams.collateralToken);
        string memory collateralSymbol;
        try collateralToken.symbol() returns (string memory symbol) {
            collateralSymbol = symbol;
        } catch {
            collateralSymbol = "COLLATERAL_TOKEN";
        }

        console.log("\n=== Next Steps ===");
        console.log("1. Your", tokenSymbol, "is now available for borrowers to borrow");
        console.log("2. You will earn interest as borrowers pay interest");
        console.log("3. You can withdraw your", tokenSymbol, "(subject to utilization)");
        console.log("4. Monitor market utilization and interest rates");
        console.log("5. Borrowers will use", collateralSymbol, "as collateral");
        console.log("6. Market ID for reference:", vm.toString(marketId));
    }
}
