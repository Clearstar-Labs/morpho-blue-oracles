// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseConstants.sol";
import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../src/morpho-chainlink/MorphoChainlinkOracleV2Factory.sol";
import "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import "../src/morpho-chainlink/interfaces/IMorphoChainlinkOracleV2.sol";
import {ChainlinkDataFeedLib} from "../src/morpho-chainlink/libraries/ChainlinkDataFeedLib.sol";

contract BaseWstUsrUsdcOracleTest is Test {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    MorphoChainlinkOracleV2Factory factory;
    
    // Base network chain ID
    uint256 constant BASE_CHAIN_ID = 8453;

    function setUp() public {
        // Fork Base network at specific block for consistent testing
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 31819496);
        require(block.chainid == BASE_CHAIN_ID, "chain isn't Base");

        // Use existing factory on Base
        factory = MorphoChainlinkOracleV2Factory(BASE_MORPHO_FACTORY);

        // Verify factory exists and has code
        require(address(factory).code.length > 0, "Factory contract not found at specified address");
    }

    function testFactoryExists() public {
        // Verify the factory is deployed and accessible
        assertTrue(address(factory) == BASE_MORPHO_FACTORY, "Factory address should match constant");
        assertTrue(address(factory).code.length > 0, "Factory should have contract code");
    }

    function testInspectOracleFeeds() public {
        // Inspect the actual decimals of each feed
        console.log("=== Oracle Feed Inspection ===");

        console.log("WSTUSR/USR feed address:", address(baseWstUsrUsrFeed));
        try baseWstUsrUsrFeed.decimals() returns (uint8 decimals) {
            console2.log("WSTUSR/USR feed decimals:", decimals);
        } catch {
            console.log("WSTUSR/USR feed decimals: ERROR - could not fetch");
        }

        console.log("USR/USD feed address:", address(baseUsrUsdFeed));
        try baseUsrUsdFeed.decimals() returns (uint8 decimals) {
            console2.log("USR/USD feed decimals:", decimals);
        } catch {
            console.log("USR/USD feed decimals: ERROR - could not fetch");
        }

        console.log("USDC/USD feed address:", address(baseUsdcUsdFeed));
        try baseUsdcUsdFeed.decimals() returns (uint8 decimals) {
            console2.log("USDC/USD feed decimals:", decimals);
        } catch {
            console.log("USDC/USD feed decimals: ERROR - could not fetch");
        }

        console.log("WSTUSR token decimals (configured):", WSTUSR_DECIMALS);
        console.log("USDC token decimals (configured):", USDC_DECIMALS);
    }

    function testDeployWstUsrUsdcOracle(bytes32 salt) public {
        // Deploy the oracle directly without CREATE2 prediction for now
        IMorphoChainlinkOracleV2 oracle = factory.createMorphoChainlinkOracleV2(
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

        // Verify deployment succeeded
        assertTrue(address(oracle) != address(0), "oracle should be deployed");
        assertTrue(factory.isMorphoChainlinkOracleV2(address(oracle)), "oracle should be registered in factory");

        console.log("Oracle deployed at:", address(oracle));

        // Calculate expected scale factor using actual feed decimals
        // SCALE_FACTOR = 10^(36 + quoteTokenDecimals + quoteFeed1Decimals + quoteFeed2Decimals - baseTokenDecimals - baseFeed1Decimals - baseFeed2Decimals)
        uint256 expectedScaleFactor = 10 ** (
            36 + USDC_DECIMALS + baseUsdcUsdFeed.decimals() + 0
            - WSTUSR_DECIMALS - baseWstUsrUsrFeed.decimals() - baseUsrUsdFeed.decimals()
        );

        // Verify oracle configuration
        assertEq(address(oracle.BASE_VAULT()), address(vaultZero), "BASE_VAULT should be zero");
        assertEq(oracle.BASE_VAULT_CONVERSION_SAMPLE(), 1, "BASE_VAULT_CONVERSION_SAMPLE should be 1");
        assertEq(address(oracle.QUOTE_VAULT()), address(vaultZero), "QUOTE_VAULT should be zero");
        assertEq(oracle.QUOTE_VAULT_CONVERSION_SAMPLE(), 1, "QUOTE_VAULT_CONVERSION_SAMPLE should be 1");
        assertEq(address(oracle.BASE_FEED_1()), address(baseWstUsrUsrFeed), "BASE_FEED_1 should be WSTUSR/USR feed");
        assertEq(address(oracle.BASE_FEED_2()), address(baseUsrUsdFeed), "BASE_FEED_2 should be USR/USD feed");
        assertEq(address(oracle.QUOTE_FEED_1()), address(baseUsdcUsdFeed), "QUOTE_FEED_1 should be USDC/USD feed");
        assertEq(address(oracle.QUOTE_FEED_2()), address(feedZero), "QUOTE_FEED_2 should be zero");
        assertEq(oracle.SCALE_FACTOR(), expectedScaleFactor, "SCALE_FACTOR should match calculation");
    }

    function testOraclePriceCalculation() public {
        // Deploy oracle with a fixed salt for testing
        bytes32 salt = keccak256("test-salt");

        IMorphoChainlinkOracleV2 oracle = factory.createMorphoChainlinkOracleV2(
            vaultZero,                      // baseVault
            1,                             // baseVaultConversionSample
            baseWstUsrUsrFeed,            // baseFeed1 (WSTUSR/USR)
            baseUsrUsdFeed,               // baseFeed2 (USR/USD)
            WSTUSR_DECIMALS,              // baseTokenDecimals
            vaultZero,                    // quoteVault
            1,                            // quoteVaultConversionSample
            baseUsdcUsdFeed,              // quoteFeed1 (USDC/USD)
            feedZero,                     // quoteFeed2
            USDC_DECIMALS,                // quoteTokenDecimals
            salt
        );

        // Get the actual price from the oracle
        uint256 actualPrice = oracle.price();

        // Expected calculation based on current feed values:
        // WSTUSR/USR = 1.08870 (8 decimals) = 108870000
        // USR/USD = 0.99989 (8 decimals) = 99989000
        // USDC/USD = 0.99997 (8 decimals) = 99997000

        // Manual calculation: (WSTUSR/USR * USR/USD) / USDC/USD * scale_factor
        // Scale factor = 10^(36 + 6 + 8 + 0 - 18 - 8 - 8) = 10^16
        uint256 wstUsrUsrPrice = 108870000; // 1.08870 with 8 decimals
        uint256 usrUsdPrice = 99989000;     // 0.99989 with 8 decimals
        uint256 usdcUsdPrice = 99997000;    // 0.99997 with 8 decimals
        uint256 scaleFactor = 10**16;

        uint256 expectedPrice = (wstUsrUsrPrice * usrUsdPrice * scaleFactor) / usdcUsdPrice;

        console.log("=== Price Calculation Verification ===");
        console.log("WSTUSR/USR price (8 decimals):", wstUsrUsrPrice);
        console.log("USR/USD price (8 decimals):", usrUsdPrice);
        console.log("USDC/USD price (8 decimals):", usdcUsdPrice);
        console.log("Scale factor:", scaleFactor);
        console.log("Expected price:", expectedPrice);
        console.log("Actual oracle price:", actualPrice);

        // Also emit the values for better visibility
        emit log_named_uint("Expected price", expectedPrice);
        emit log_named_uint("Actual oracle price", actualPrice);

        // Allow for small tolerance due to precision differences (±0.1%)
        uint256 tolerance = expectedPrice * 1 / 1000;
        uint256 lowerBound = expectedPrice - tolerance;
        uint256 upperBound = expectedPrice + tolerance;

        assertGe(actualPrice, lowerBound, "Oracle price should be within expected range (lower bound)");
        assertLe(actualPrice, upperBound, "Oracle price should be within expected range (upper bound)");
        assertGt(actualPrice, 0, "Oracle price should be greater than 0");
    }

    function testOracleWithDifferentDecimals() public {
        // Test with different decimal assumptions to ensure flexibility
        uint256 alternativeWstUsrDecimals = 6; // Example: if WSTUSR had 6 decimals
        
        bytes32 salt = keccak256("alternative-decimals-test");
        
        IMorphoChainlinkOracleV2 oracle = factory.createMorphoChainlinkOracleV2(
            vaultZero,
            1,
            baseWstUsrUsrFeed,
            baseUsrUsdFeed,
            alternativeWstUsrDecimals,     // Different base token decimals
            vaultZero,
            1,
            baseUsdcUsdFeed,
            feedZero,
            USDC_DECIMALS,
            salt
        );

        // Calculate expected scale factor with different decimals
        uint256 expectedScaleFactor = 10 ** (36 + USDC_DECIMALS + 8 + 0 - alternativeWstUsrDecimals - 8 - 8);
        
        assertEq(oracle.SCALE_FACTOR(), expectedScaleFactor, "SCALE_FACTOR should adjust for different decimals");
    }

    // Helper function to compute CREATE2 address
    function _computeCreate2Address(bytes32 salt, bytes32 initCodeHash, address deployer)
        internal
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            initCodeHash
        )))));
    }

    // Helper function to hash init code
    function _hashInitCode(bytes memory creationCode, bytes memory constructorArgs)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(creationCode, constructorArgs));
    }
}
