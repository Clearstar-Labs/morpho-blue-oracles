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

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) external;

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

contract SupplyWstUsrCollateral is Script {
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
    // Address 0x6539519e69343535a2af6583d9bae3ad74c6a293 has 2.000793 wstUSR balance
    uint256 constant DEFAULT_SUPPLY_AMOUNT = 2000793000000000000; // ~2.000793 wstUSR
    
    function getSupplyAmount(address user) internal view returns (uint256) {
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

        // Get supply amount (may depend on user's balance)
        uint256 supplyAmount = getSupplyAmount(user);

        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        console.log("=== Supplying wstUSR Collateral to Morpho ===");
        console.log("Morpho contract:", MORPHO);
        console.log("Market ID:", vm.toString(marketId));
        console.log("wstUSR token:", WSTUSR);
        console.log("User address:", user);
        console.log("Supply amount:", supplyAmount);
        
        // Check wstUSR balance
        IERC20 wstUsrToken = IERC20(WSTUSR);
        uint256 balance = wstUsrToken.balanceOf(user);
        console.log("wstUSR balance:", balance);
        
        require(balance >= supplyAmount, "Insufficient wstUSR balance");
        
        // Check current allowance
        uint256 currentAllowance = wstUsrToken.allowance(user, MORPHO);
        console.log("Current allowance:", currentAllowance);
        
        vm.startBroadcast();
        
        // Approve if needed
        if (currentAllowance < supplyAmount) {
            console.log("Approving wstUSR spend...");
            bool success = wstUsrToken.approve(MORPHO, supplyAmount);
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
        
        // Supply collateral
        console.log("\n=== Supplying Collateral ===");
        try morpho.supplyCollateral(marketParams, supplyAmount, user, "") {
            console.log("Collateral supplied successfully!");
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
        console.log("Collateral added:", collateralAfter - collateralBefore);
        console.log("Total collateral:", collateralAfter);
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. You can now borrow USDC against this collateral");
        console.log("2. Maximum borrowable (91.5% LTV): Calculate based on oracle price");
        console.log("3. Monitor your position health");
        console.log("4. Use scripts/BorrowUsdc.s.sol to borrow USDC");
    }
}
