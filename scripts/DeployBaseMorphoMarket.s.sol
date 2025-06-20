// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

// Morpho Blue interface
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}

contract DeployBaseMorphoMarket is Script {
    // Base network chain ID
    uint256 constant BASE_CHAIN_ID = 8453;
    
    // Contract addresses on Base
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    
    // Token addresses on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WSTUSR = 0xC33dCb063E3D9Da00C3fa0a7Cbf9f6670cd7C132;
    
    // Oracle address (deployed in previous script)
    address constant ORACLE = 0x31fB76310E7AA59f4994af8cb6a420c39669604A;
    
    // LLTV: 91.5% = 0.915 = 915000000000000000 (18 decimals)
    uint256 constant LLTV = 915000000000000000;

    // Function to calculate market ID from parameters
    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
    
    function run() external {
        // Ensure we're on Base network
        require(block.chainid == BASE_CHAIN_ID, "Must be on Base network");

        console.log("=== Deploying Morpho Market on Base ===");
        console.log("Morpho contract:", MORPHO);
        console.log("Loan token (USDC):", USDC);
        console.log("Collateral token (wstUSR):", WSTUSR);
        console.log("Oracle:", ORACLE);
        console.log("IRM (Adaptive Curve):", ADAPTIVE_CURVE_IRM);
        console.log("LLTV (91.5%):");
        console.log("LLTV value:", LLTV);
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Create market parameters
        IMorpho.MarketParams memory marketParams = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: WSTUSR,
            oracle: ORACLE,
            irm: ADAPTIVE_CURVE_IRM,
            lltv: LLTV
        });
        
        // Calculate market ID before creation
        bytes32 marketId = getMarketId(marketParams);
        console.log("Calculated Market ID:", vm.toString(marketId));

        // Deploy the market
        IMorpho morpho = IMorpho(MORPHO);

        console.log("\n=== Creating Market ===");
        try morpho.createMarket(marketParams) {
            console.log("Market created successfully!");
        } catch Error(string memory reason) {
            console.log("Market creation failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Market creation failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Market creation failed");
        }

        // Verify market was created correctly
        console.log("\n=== Verifying Market Parameters ===");
        IMorpho.MarketParams memory createdMarket;
        try morpho.idToMarketParams(marketId) returns (IMorpho.MarketParams memory params) {
            createdMarket = params;
            console.log("Market parameters retrieved successfully");
        } catch Error(string memory reason) {
            console.log("Failed to retrieve market parameters:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Failed to retrieve market parameters with low-level error");
            console.logBytes(lowLevelData);
            revert("Failed to retrieve market parameters");
        }
        
        console.log("\n=== Market Verification ===");
        console.log("Loan Token:", createdMarket.loanToken);
        console.log("Collateral Token:", createdMarket.collateralToken);
        console.log("Oracle:", createdMarket.oracle);
        console.log("IRM:", createdMarket.irm);
        console.log("LLTV:", createdMarket.lltv);
        
        // Verify all parameters match
        require(createdMarket.loanToken == USDC, "Loan token mismatch");
        require(createdMarket.collateralToken == WSTUSR, "Collateral token mismatch");
        require(createdMarket.oracle == ORACLE, "Oracle mismatch");
        require(createdMarket.irm == ADAPTIVE_CURVE_IRM, "IRM mismatch");
        require(createdMarket.lltv == LLTV, "LLTV mismatch");
        
        console.log("\n[SUCCESS] All parameters verified successfully!");
        
        vm.stopBroadcast();
        
        // Market information
        console.log("\n=== Market Summary ===");
        console.log("Market ID:", vm.toString(marketId));
        console.log("Loan-to-Value Ratio: 91.5%");
        console.log("Users can now:");
        console.log("1. Supply wstUSR as collateral");
        console.log("2. Borrow USDC against wstUSR collateral (up to 91.5% LTV)");
        console.log("3. USDC suppliers can lend USDC to earn interest");
        console.log("4. Borrowers pay interest on borrowed USDC");
        
        console.log("\n=== Integration Details ===");
        console.log("Use this Market ID in your frontend/integration:");
        console.log("Market ID:", vm.toString(marketId));
        console.log("Morpho Contract:", MORPHO);
        console.log("Oracle provides WSTUSR/USDC price from:");
        console.log("- WSTUSR/USR (Pyth): 0x17D099fc623bd06CFE4861d874704Af184773c75");
        console.log("- USR/USD (Chainlink): 0x4a595E0a62E50A2E5eC95A70c8E612F9746af006");
        console.log("- USDC/USD (Chainlink): 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B");
    }
}
