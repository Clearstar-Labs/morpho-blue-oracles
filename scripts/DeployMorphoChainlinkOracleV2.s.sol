// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

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

// Minimal oracle interface
interface IOracle { function price() external view returns (uint256); }

// Minimal ERC4626 interface for convertToAssets
interface IERC4626Minimal { function convertToAssets(uint256 shares) external view returns (uint256); }

contract DeployMorphoChainlinkOracleV2 is Script {
    // Expose last deployed oracle for tests/integration
    address public latestOracle;
    
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
        require(factory != address(0), "Factory address is zero");

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
        // Mirror constructor checks for early failure
        require(baseVault != address(0) || baseVaultConversionSample == 1, "base vault zero -> base sample must be 1");
        require(baseVault == address(0) || baseVaultConversionSample != 0, "base vault sample is zero");
        address baseFeed1 = vm.envAddress("BASE_FEED_1");
        // If both base feeds are zero, ensure base vault is set (so price path exists)
        // Note: baseFeed2 read happens below; we check after reading it.
        
        // BASE_FEED_2 is optional (can be zero address)
        address baseFeed2;
        try vm.envAddress("BASE_FEED_2") returns (address feed) {
            baseFeed2 = feed;
        } catch {
            baseFeed2 = address(0);
        }
        
        uint256 baseTokenDecimals = vm.envUint("BASE_TOKEN_DECIMALS");
        require(baseTokenDecimals <= 36, "baseTokenDecimals too large");

        // If both base feeds are zero, baseVault must be nonzero
        require(!(baseFeed1 == address(0) && baseFeed2 == address(0)) || baseVault != address(0), "missing base pricing path");

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
        // Mirror constructor checks for early failure
        require(quoteVault != address(0) || quoteVaultConversionSample == 1, "quote vault zero -> quote sample must be 1");
        require(quoteVault == address(0) || quoteVaultConversionSample != 0, "quote vault sample is zero");
        address quoteFeed1 = vm.envAddress("QUOTE_FEED_1");
        
        // QUOTE_FEED_2 is optional (can be zero address)
        address quoteFeed2;
        try vm.envAddress("QUOTE_FEED_2") returns (address feed) {
            quoteFeed2 = feed;
        } catch {
            quoteFeed2 = address(0);
        }
        
        uint256 quoteTokenDecimals = vm.envUint("QUOTE_TOKEN_DECIMALS");
        require(quoteTokenDecimals <= 36, "quoteTokenDecimals too large");

        // If both quote feeds are zero and quote vault is zero, path must still make sense
        require(!(quoteFeed1 == address(0) && quoteFeed2 == address(0)) || quoteVault == address(0) || quoteVaultConversionSample != 0, "invalid quote setup");
        
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
        
        console2.log("=== Deploying MorphoChainlinkOracleV2 ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Factory:", factory);
        console2.log("Base Vault:", baseVault);
        console2.log("Base Symbol:", baseSymbol);
        console2.log("Base Vault Conversion Sample:", baseVaultConversionSample);
        console2.log("Quote Vault:", quoteVault);
        console2.log("Quote Symbol:", quoteSymbol);
        console2.log("Quote Vault Conversion Sample:", quoteVaultConversionSample);
        console2.log("Base Feed 1:", baseFeed1);
        console2.log("Base Feed 2:", baseFeed2);
        console2.log("Base Token Decimals:", baseTokenDecimals);
        console2.log("Quote Feed 1:", quoteFeed1);
        console2.log("Quote Feed 2:", quoteFeed2);
        console2.log("Quote Token Decimals:", quoteTokenDecimals);
        console2.log("Salt:", vm.toString(salt));


        // Allow disabling broadcast in tests via env var
        bool doBroadcast;
        try vm.envBool("SCRIPT_BROADCAST") returns (bool b) {
            doBroadcast = b;
        } catch {
            doBroadcast = true;
        }

        if (doBroadcast) {
            // Prefer explicit private key if available, else default
            try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
                vm.startBroadcast(pk);
            } catch {
                vm.startBroadcast();
            }
        }
        
        // Deploy oracle using factory
        IMorphoChainlinkOracleV2Factory factoryContract = IMorphoChainlinkOracleV2Factory(factory);
        
        console2.log("\n=== Creating Oracle ===");
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
            console2.log("Oracle deployed successfully!");
            console2.log("Oracle address:", oracle);
        } catch Error(string memory reason) {
            console2.log("Oracle deployment failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Oracle deployment failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Oracle deployment failed");
        }
        
        // Verify oracle was created correctly
        bool isValidOracle = factoryContract.isMorphoChainlinkOracleV2(oracle);
        require(isValidOracle, "Oracle verification failed");
        
        if (doBroadcast) vm.stopBroadcast();

        // Record latest oracle for tests/consumers
        latestOracle = oracle;

        // Post-deploy sanity checks
        // - If base feeds and quote feeds are zero addresses and quote vault is zero,
        //   we can compute an expected price: 1e36 * convertToAssets(bCS) / bCS.
        uint256 expectedPrice;
        bool canComputeExpected = (baseFeed1 == address(0) && baseFeed2 == address(0) && quoteFeed1 == address(0) && quoteFeed2 == address(0) && quoteVault == address(0) && baseVault != address(0) && baseVaultConversionSample != 0);
        if (canComputeExpected) {
            expectedPrice = IERC4626Minimal(baseVault).convertToAssets(baseVaultConversionSample) * 1e36 / baseVaultConversionSample;
        }

        uint256 oraclePrice;
        try IOracle(oracle).price() returns (uint256 p) {
            oraclePrice = p;
        } catch {
            oraclePrice = 0;
        }

        console2.log("\n=== Deployment Summary ===");
        console2.log("Oracle Address:", oracle);
        console2.log("Oracle Type: MorphoChainlinkOracleV2");
        console2.log("Base Token:", baseSymbol);
        console2.log("Quote Token:", quoteSymbol);
        console2.log("Base Vault Conversion Sample:", baseVaultConversionSample);
        console2.log("Quote Vault Conversion Sample:", quoteVaultConversionSample);
        console2.log("Computed Expected Price (if applicable):", expectedPrice);
        console2.log("Oracle Price:", oraclePrice);
        console2.log("Computed Expected Price (if applicable):", expectedPrice);
        console2.log("Oracle Price:", oraclePrice);
        console2.log("Factory Verified:", true);
        console2.log("Factory Verified: true");

        console2.log("\n=== Integration Details ===");
        console2.log("Use this oracle address in your Morpho market:");
        console2.log("ORACLE_ADDRESS=", oracle);
        console2.log("Factory:", factory);
        
        console2.log("\n=== Next Steps ===");
        console2.log("1. Test the oracle by calling price() function");
        console2.log("2. Use this oracle address in your market deployment");
        console2.log("3. Verify the oracle is returning expected prices");
        console2.log("4. Deploy your Morpho market with this oracle");
    }
}
