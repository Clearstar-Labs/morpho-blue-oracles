// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/morpho-chainlink/MorphoChainlinkOracleV2Factory.sol";
import "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import "../test/helpers/BaseConstants.sol";

contract DeployBaseWstUsrUsdcOracle is Script {
    // Base network chain ID
    uint256 constant BASE_CHAIN_ID = 8453;
    
    function run() external {
        // Ensure we're on Base network
        require(block.chainid == BASE_CHAIN_ID, "Must be on Base network");
        
        // Start broadcasting transactions
        vm.startBroadcast();

        // Use existing factory on Base
        MorphoChainlinkOracleV2Factory factory = MorphoChainlinkOracleV2Factory(BASE_MORPHO_FACTORY);
        console.log("Using existing factory at:", address(factory));
        
        // Generate a salt for CREATE2 deployment
        bytes32 salt = keccak256(abi.encodePacked("WSTUSR-USDC-Oracle-v1", block.timestamp));
        
        // Deploy the oracle
        MorphoChainlinkOracleV2 oracle = factory.createMorphoChainlinkOracleV2(
            vaultZero,                      // baseVault (WSTUSR is not a vault)
            1,                             // baseVaultConversionSample
            baseWstUsrUsrFeed,            // baseFeed1 (WSTUSR/USR Pyth oracle)
            baseUsrUsdFeed,               // baseFeed2 (USR/USD feed)
            WSTUSR_DECIMALS,              // baseTokenDecimals
            vaultZero,                    // quoteVault (USDC is not a vault)
            1,                            // quoteVaultConversionSample
            baseUsdcUsdFeed,              // quoteFeed1 (USDC/USD feed)
            feedZero,                     // quoteFeed2 (no second quote feed)
            USDC_DECIMALS,                // quoteTokenDecimals
            salt
        );
        
        console.log("Oracle deployed at:", address(oracle));
        console.log("Salt used:", vm.toString(salt));
        
        // Log oracle configuration for verification
        console.log("=== Oracle Configuration ===");
        console.log("BASE_VAULT:", address(oracle.BASE_VAULT()));
        console.log("BASE_VAULT_CONVERSION_SAMPLE:", oracle.BASE_VAULT_CONVERSION_SAMPLE());
        console.log("BASE_FEED_1 (WSTUSR/USR):", address(oracle.BASE_FEED_1()));
        console.log("BASE_FEED_2 (USR/USD):", address(oracle.BASE_FEED_2()));
        console.log("QUOTE_VAULT:", address(oracle.QUOTE_VAULT()));
        console.log("QUOTE_VAULT_CONVERSION_SAMPLE:", oracle.QUOTE_VAULT_CONVERSION_SAMPLE());
        console.log("QUOTE_FEED_1 (USDC/USD):", address(oracle.QUOTE_FEED_1()));
        console.log("QUOTE_FEED_2:", address(oracle.QUOTE_FEED_2()));
        console.log("SCALE_FACTOR:", oracle.SCALE_FACTOR());
        
        // Try to get the current price (will fail if feeds are not properly set up)
        try oracle.price() returns (uint256 price) {
            console.log("Current price (WSTUSR in USDC terms, scaled by 1e36):", price);
        } catch Error(string memory reason) {
            console.log("Price call failed:", reason);
        } catch (bytes memory) {
            console.log("Price call failed with low-level error");
        }
        
        vm.stopBroadcast();

        // Next steps
        console.log("\n=== Next Steps ===");
        console.log("1. Verify the oracle feeds are working correctly");
        console.log("2. Update your Morpho market configuration to use this oracle:");
        console.log("   Oracle Address:", address(oracle));
        console.log("3. Ensure all three price feeds are properly maintained:");
        console.log("   - WSTUSR/USR Pyth feed:", address(baseWstUsrUsrFeed));
        console.log("   - USR/USD feed:", address(baseUsrUsdFeed));
        console.log("   - USDC/USD feed:", address(baseUsdcUsdFeed));
    }
}
