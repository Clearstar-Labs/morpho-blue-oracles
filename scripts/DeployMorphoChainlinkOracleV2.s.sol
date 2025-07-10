// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

// MorphoChainlinkOracleV2Factory interface
interface IMorphoChainlinkOracleV2Factory {
    function createMorphoChainlinkOracleV2(
        address baseVault,
        uint256 baseVaultConversionSample,
        address baseFeed1,
        address baseFeed2,
        uint256 baseTokenDecimals,
        address quoteVault,
        uint256 quoteVaultConversionSample,
        address quoteFeed1,
        address quoteFeed2,
        uint256 quoteTokenDecimals,
        bytes32 salt
    ) external returns (address oracle);

    function isMorphoChainlinkOracleV2(address oracle) external view returns (bool);
}

// IERC20 interface for token info
interface IERC20 {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract DeployMorphoChainlinkOracleV2 is Script {
    
    function getTokenInfo(address token) internal view returns (string memory symbol, uint8 decimals) {
        try IERC20(token).symbol() returns (string memory _symbol) {
            symbol = _symbol;
        } catch {
            symbol = "TOKEN";
        }
        
        try IERC20(token).decimals() returns (uint8 _decimals) {
            decimals = _decimals;
        } catch {
            decimals = 18;
        }
    }
    
    function run() external {
        // Get all required parameters from environment variables
        address factory = vm.envAddress("MORPHO_CHAINLINK_ORACLE_V2_FACTORY");

        // BASE_VAULT is optional (can be zero address)
        address baseVault;
        try vm.envAddress("BASE_VAULT") returns (address vault) {
            baseVault = vault;
        } catch {
            baseVault = address(0);
        }

        // BASE_VAULT_CONVERSION_SAMPLE is optional (defaults to 1 when no vault)
        uint256 baseVaultConversionSample;
        try vm.envUint("BASE_VAULT_CONVERSION_SAMPLE") returns (uint256 sample) {
            baseVaultConversionSample = sample;
        } catch {
            baseVaultConversionSample = 1;
        }
        address baseFeed1 = vm.envAddress("BASE_FEED_1");
        
        // BASE_FEED_2 is optional (can be zero address)
        address baseFeed2;
        try vm.envAddress("BASE_FEED_2") returns (address feed) {
            baseFeed2 = feed;
        } catch {
            baseFeed2 = address(0);
        }
        
        uint256 baseTokenDecimals = vm.envUint("BASE_TOKEN_DECIMALS");

        // QUOTE_VAULT is optional (can be zero address)
        address quoteVault;
        try vm.envAddress("QUOTE_VAULT") returns (address vault) {
            quoteVault = vault;
        } catch {
            quoteVault = address(0);
        }

        // QUOTE_VAULT_CONVERSION_SAMPLE is optional (defaults to 1 when no vault)
        uint256 quoteVaultConversionSample;
        try vm.envUint("QUOTE_VAULT_CONVERSION_SAMPLE") returns (uint256 sample) {
            quoteVaultConversionSample = sample;
        } catch {
            quoteVaultConversionSample = 1;
        }
        address quoteFeed1 = vm.envAddress("QUOTE_FEED_1");
        
        // QUOTE_FEED_2 is optional (can be zero address)
        address quoteFeed2;
        try vm.envAddress("QUOTE_FEED_2") returns (address feed) {
            quoteFeed2 = feed;
        } catch {
            quoteFeed2 = address(0);
        }
        
        uint256 quoteTokenDecimals = vm.envUint("QUOTE_TOKEN_DECIMALS");
        
        // Generate salt from environment or use default
        bytes32 salt;
        try vm.envBytes32("SALT") returns (bytes32 _salt) {
            salt = _salt;
        } catch {
            salt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        }
        
        // Get token symbols for display
        string memory baseSymbol;
        string memory quoteSymbol;

        if (baseVault != address(0)) {
            (baseSymbol,) = getTokenInfo(baseVault);
        } else {
            baseSymbol = "N/A";
        }

        if (quoteVault != address(0)) {
            (quoteSymbol,) = getTokenInfo(quoteVault);
        } else {
            quoteSymbol = "N/A";
        }
        
        console.log("=== Deploying MorphoChainlinkOracleV2 ===");
        console.log("Chain ID:", block.chainid);
        console.log("Factory:", factory);
        console.log("Base Vault:", baseVault);
        console.log("Base Symbol:", baseSymbol);
        console.log("Base Vault Conversion Sample:", baseVaultConversionSample);
        console.log("Base Feed 1:", baseFeed1);
        console.log("Base Feed 2:", baseFeed2);
        console.log("Base Token Decimals:", baseTokenDecimals);
        console.log("Quote Vault:", quoteVault);
        console.log("Quote Symbol:", quoteSymbol);
        console.log("Quote Vault Conversion Sample:", quoteVaultConversionSample);
        console.log("Quote Feed 1:", quoteFeed1);
        console.log("Quote Feed 2:", quoteFeed2);
        console.log("Quote Token Decimals:", quoteTokenDecimals);
        console.log("Salt:", vm.toString(salt));
        
        vm.startBroadcast();
        
        // Deploy oracle using factory
        IMorphoChainlinkOracleV2Factory factoryContract = IMorphoChainlinkOracleV2Factory(factory);
        
        console.log("\n=== Creating Oracle ===");
        address oracle;
        try factoryContract.createMorphoChainlinkOracleV2(
            baseVault,
            baseVaultConversionSample,
            baseFeed1,
            baseFeed2,
            baseTokenDecimals,
            quoteVault,
            quoteVaultConversionSample,
            quoteFeed1,
            quoteFeed2,
            quoteTokenDecimals,
            salt
        ) returns (address _oracle) {
            oracle = _oracle;
            console.log("Oracle deployed successfully!");
            console.log("Oracle address:", oracle);
        } catch Error(string memory reason) {
            console.log("Oracle deployment failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Oracle deployment failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Oracle deployment failed");
        }
        
        // Verify oracle was created correctly
        bool isValidOracle = factoryContract.isMorphoChainlinkOracleV2(oracle);
        require(isValidOracle, "Oracle verification failed");
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Oracle Address:", oracle);
        console.log("Oracle Type: MorphoChainlinkOracleV2");
        console.log("Base Token:", baseSymbol);
        console.log("Quote Token:", quoteSymbol);
        console.log("Factory Verified: true");
        
        console.log("\n=== Integration Details ===");
        console.log("Use this oracle address in your Morpho market:");
        console.log("ORACLE_ADDRESS=", oracle);
        console.log("Factory:", factory);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Test the oracle by calling price() function");
        console.log("2. Use this oracle address in your market deployment");
        console.log("3. Verify the oracle is returning expected prices");
        console.log("4. Deploy your Morpho market with this oracle");
    }
}
