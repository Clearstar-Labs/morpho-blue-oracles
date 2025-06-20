// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

// IERC20 interface for token operations
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
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

contract SupplyUsdc is Script {
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
    
    // Supply amount (can be overridden via environment variable)
    // Address 0x6539519E69343535a2aF6583D9BAE3AD74c6A293 has 2.136803 USDC balance
    uint256 constant DEFAULT_SUPPLY_AMOUNT = 2136803; // ~2.136803 USDC
    
    function getSupplyAmount() internal view returns (uint256) {
        try vm.envUint("SUPPLY_AMOUNT") returns (uint256 amount) {
            return amount;
        } catch {
            return DEFAULT_SUPPLY_AMOUNT;
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
    
    function run() external {
        // Ensure we're on Base network
        require(block.chainid == BASE_CHAIN_ID, "Must be on Base network");
        
        // Get user address
        address user = vm.addr(vm.envUint("PRIVATE_KEY"));
        
        // Get supply amount
        uint256 supplyAmount = getSupplyAmount();
        
        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);
        
        console.log("=== Supplying USDC to Morpho Market ===");
        console.log("Morpho contract:", MORPHO);
        console.log("Market ID:", vm.toString(marketId));
        console.log("USDC token:", USDC);
        console.log("User address:", user);
        console.log("Supply amount:", supplyAmount);
        
        // Check USDC balance
        IERC20 usdcToken = IERC20(USDC);
        uint256 balance = usdcToken.balanceOf(user);
        console.log("USDC balance:", balance);
        
        require(balance >= supplyAmount, "Insufficient USDC balance");
        
        // Check current allowance
        uint256 currentAllowance = usdcToken.allowance(user, MORPHO);
        console.log("Current allowance:", currentAllowance);
        
        vm.startBroadcast();
        
        // Approve if needed
        if (currentAllowance < supplyAmount) {
            console.log("Approving USDC spend...");
            bool success = usdcToken.approve(MORPHO, supplyAmount);
            require(success, "Approval failed");
            console.log("Approval successful");
        } else {
            console.log("Sufficient allowance already exists");
        }
        
        // Check position before supply
        IMorpho morpho = IMorpho(MORPHO);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);
        
        console.log("\n=== Position Before Supply ===");
        console.log("Supply shares:", supplySharesBefore);
        console.log("Borrow shares:", borrowSharesBefore);
        console.log("Collateral:", collateralBefore);
        
        // Supply USDC (using 0 for shares means we want to supply exact assets)
        console.log("\n=== Supplying USDC ===");
        try morpho.supply(marketParams, supplyAmount, 0, user, "") returns (uint256 assetsSupplied, uint256 sharesReturned) {
            console.log("USDC supplied successfully!");
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
        console.log("USDC supplied to market for borrowers");
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Your USDC is now available for borrowers to borrow");
        console.log("2. You will earn interest as borrowers pay interest");
        console.log("3. You can withdraw your USDC (subject to utilization)");
        console.log("4. Monitor market utilization and interest rates");
        console.log("5. Use scripts/WithdrawUsdc.s.sol to withdraw later");
    }
}
