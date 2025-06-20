// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

// IERC20 interface for token operations
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
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

contract BorrowUsdc is Script {
    // Base network chain ID
    uint256 constant BASE_CHAIN_ID = 8453;
    
    // Contract addresses on Base
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    
    // Token addresses on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WSTUSR = 0xB67675158B412D53fe6B68946483ba920b135bA1;
    
    // Oracle address
    address constant ORACLE = 0x31fB76310E7AA59f4994af8cb6a420c39669604A;
    
    // LLTV: 91.5%
    uint256 constant LLTV = 915000000000000000;
    
    // Borrow amount (can be overridden via environment variable)
    uint256 constant DEFAULT_BORROW_AMOUNT = 500000000; // 500 USDC (6 decimals)
    
    function getBorrowAmount() internal view returns (uint256) {
        try vm.envUint("BORROW_AMOUNT") returns (uint256 amount) {
            return amount;
        } catch {
            return DEFAULT_BORROW_AMOUNT;
        }
    }
    
    function getMarketParams() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: WSTUSR,
            oracle: ORACLE,
            irm: ADAPTIVE_CURVE_IRM,
            lltv: LLTV
        });
    }
    
    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
    
    function calculateMaxBorrow(uint256 collateralAmount, uint256 oraclePrice) internal pure returns (uint256) {
        // Oracle price is scaled by 1e36, collateral has 18 decimals, USDC has 6 decimals
        // collateralValue = collateralAmount * oraclePrice / 1e36 (in USDC terms with 6 decimals)
        // maxBorrow = collateralValue * LLTV / 1e18
        return (collateralAmount * oraclePrice * LLTV) / (1e36 * 1e18);
    }
    
    function run() external {
        // Ensure we're on Base network
        require(block.chainid == BASE_CHAIN_ID, "Must be on Base network");
        
        // Get user address
        address user = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Get borrow amount
        uint256 borrowAmount = getBorrowAmount();
        
        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);
        
        console.log("=== Borrowing USDC from Morpho Market ===");
        console.log("Morpho contract:", MORPHO);
        console.log("Market ID:", vm.toString(marketId));
        console.log("USDC token:", USDC);
        console.log("User address:", user);
        console.log("Borrow amount:", borrowAmount);
        
        // Check current position
        IMorpho morpho = IMorpho(MORPHO);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);
        
        console.log("\n=== Current Position ===");
        console.log("Supply shares:", supplySharesBefore);
        console.log("Borrow shares:", borrowSharesBefore);
        console.log("Collateral (wstUSR):", collateralBefore);
        
        // Check if user has collateral
        require(collateralBefore > 0, "No collateral found. Supply wstUSR collateral first using SupplyWstUsrCollateral.s.sol");
        
        // Get current oracle price
        IOracle oracle = IOracle(ORACLE);
        uint256 currentPrice;
        try oracle.price() returns (uint256 price) {
            currentPrice = price;
            console.log("Current wstUSR/USDC price (scaled by 1e36):", currentPrice);
        } catch {
            console.log("Warning: Could not fetch oracle price");
            currentPrice = 1e36; // Fallback to 1:1 ratio
        }
        
        // Calculate maximum borrowable amount
        uint256 maxBorrowable = calculateMaxBorrow(collateralBefore, currentPrice);
        console.log("Maximum borrowable USDC:", maxBorrowable);
        console.log("Requested borrow amount:", borrowAmount);
        
        // Safety check
        require(borrowAmount <= maxBorrowable, "Borrow amount exceeds maximum borrowable (91.5% LTV)");
        
        // Calculate health factor after borrow
        uint256 healthFactorAfter = (maxBorrowable * 1e18) / borrowAmount;
        console.log("Health factor after borrow (1e18 = 100%):", healthFactorAfter);
        
        if (healthFactorAfter < 1.1e18) {
            console.log("WARNING: Health factor will be below 110% - risky position!");
        }
        
        // Check USDC balance before borrow
        IERC20 usdcToken = IERC20(USDC);
        uint256 usdcBalanceBefore = usdcToken.balanceOf(user);
        console.log("USDC balance before borrow:", usdcBalanceBefore);
        
        vm.startBroadcast();
        
        // Borrow USDC (using 0 for shares means we want to borrow exact assets)
        console.log("\n=== Borrowing USDC ===");
        try morpho.borrow(marketParams, borrowAmount, 0, user, user) returns (uint256 assetsBorrowed, uint256 sharesBorrowed) {
            console.log("USDC borrowed successfully!");
            console.log("Assets borrowed:", assetsBorrowed);
            console.log("Shares borrowed:", sharesBorrowed);
        } catch Error(string memory reason) {
            console.log("Borrow failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Borrow failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Borrow failed");
        }
        
        // Check position after borrow
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) = morpho.position(marketId, user);
        
        console.log("\n=== Position After Borrow ===");
        console.log("Supply shares:", supplySharesAfter);
        console.log("Borrow shares:", borrowSharesAfter);
        console.log("Collateral:", collateralAfter);
        
        // Check USDC balance after borrow
        uint256 usdcBalanceAfter = usdcToken.balanceOf(user);
        console.log("USDC balance after borrow:", usdcBalanceAfter);
        
        console.log("\n=== Borrow Summary ===");
        console.log("Borrow shares added:", borrowSharesAfter - borrowSharesBefore);
        console.log("Total borrow shares:", borrowSharesAfter);
        console.log("USDC received:", usdcBalanceAfter - usdcBalanceBefore);
        console.log("Collateral used:", collateralBefore);
        
        vm.stopBroadcast();
        
        console.log("\n=== Important Notes ===");
        console.log("1. You now owe USDC that accrues interest over time");
        console.log("2. Monitor your position health factor regularly");
        console.log("3. If health factor drops below 100%, you risk liquidation");
        console.log("4. Consider repaying or adding collateral if price moves against you");
        console.log("5. Use scripts/RepayUsdc.s.sol to repay the loan");
        
        console.log("\n=== Risk Management ===");
        console.log("Current LTV:", (borrowAmount * 1e18) / maxBorrowable, "/ 1e18");
        console.log("Liquidation threshold: 91.5%");
        console.log("Recommended: Keep LTV below 80% for safety buffer");
    }
}
