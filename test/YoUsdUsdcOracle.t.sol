// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import {MorphoChainlinkOracleV2} from "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import {IERC4626} from "../src/morpho-chainlink/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "../src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";
import {ErrorsLib} from "../src/morpho-chainlink/libraries/ErrorsLib.sol";

// Reuse helpers (zero addresses as typed)
import {vaultZero, feedZero} from "./helpers/Constants.sol";

contract YoUsdUsdcOracleTest is Test {
    // yoUSD (ERC4626) vault address (provided by user)
    IERC4626 constant YO_USD_VAULT = IERC4626(0x0000000f2eB9f69274678c76222B35eEc7588a65);

    // Token decimals per user config
    uint256 constant USDC_DECIMALS = 6;

    function setUp() public {
        // Fork Ethereum mainnet to read live convertToAssets from yoUSD
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        require(block.chainid == 1, "chain isn't Ethereum");
    }

    /// Math reference:
    /// With base = yoUSD vault, quote = USDC, all feeds = 0x0, quote vault = 0x0,
    /// SCALE_FACTOR = 1e(36 + dQ - dB) * qCS / bCS. With dQ=dB=6 and qCS=1 -> SCALE_FACTOR = 1e36 / bCS.
    /// price() = SCALE_FACTOR * baseVault.convertToAssets(bCS) = 1e36 * convertToAssets(bCS) / bCS.
    function testYoUsdUsdc_OracleMatchesVaultExchangeRate() public {
        // choose a sufficiently large sample for precision; most 4626 vaults use 18-decimal shares
        uint256 baseSample = 1e18;

        MorphoChainlinkOracleV2 oracle = new MorphoChainlinkOracleV2(
            YO_USD_VAULT,
            baseSample,
            feedZero, // BASE_FEED_1 = 1
            feedZero, // BASE_FEED_2 = 1
            USDC_DECIMALS, // base token decimals = underlying (USDC)
            vaultZero, // QUOTE_VAULT = 1
            1, // QUOTE_VAULT_CONVERSION_SAMPLE must be 1 when vault is zero
            feedZero, // QUOTE_FEED_1 = 1
            feedZero, // QUOTE_FEED_2 = 1
            USDC_DECIMALS // quote token decimals = USDC
        );

        uint256 expected = YO_USD_VAULT.convertToAssets(baseSample) * 1e36 / baseSample;
        uint256 actual = oracle.price();

        // Allow very small rounding diff due to integer division
        assertApproxEqRel(actual, expected, 1e12); // 0.0001% tolerance
    }

    function testRevertsWhenBaseSampleZero() public {
        vm.expectRevert(bytes(ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_ZERO));
        new MorphoChainlinkOracleV2(
            YO_USD_VAULT,
            0,
            feedZero,
            feedZero,
            USDC_DECIMALS,
            vaultZero,
            1,
            feedZero,
            feedZero,
            USDC_DECIMALS
        );
    }

    function testRevertsWhenQuoteVaultZeroButQuoteSampleNotOne(uint256 badSample) public {
        badSample = bound(badSample, 2, type(uint256).max);
        vm.expectRevert(bytes(ErrorsLib.VAULT_CONVERSION_SAMPLE_IS_NOT_ONE));
        new MorphoChainlinkOracleV2(
            YO_USD_VAULT,
            1e18,
            feedZero,
            feedZero,
            USDC_DECIMALS,
            vaultZero,
            badSample, // must be 1 when quote vault is 0x0
            feedZero,
            feedZero,
            USDC_DECIMALS
        );
    }
}

