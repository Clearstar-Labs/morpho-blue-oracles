// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import "../src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";
import "../src/morpho-chainlink/interfaces/IERC4626.sol";

contract HemiPtBfBtcOracleTest is Test {
    AggregatorV3Interface internal constant PT_BFBTC_FEED =
        AggregatorV3Interface(0x5a8b1Fc452D8F1151A07b743687583050E4FaD0f);

    uint8 internal constant PT_BFBTC_DECIMALS = 8;
    uint8 internal constant HEMI_BTC_DECIMALS = 8;

    bool internal skipEnv;

    function setUp() public {
        if (!_hasEnv("HEMI_RPC_URL")) {
            console2.log("HEMI_RPC_URL not set; skipping Hemi PT bfBTC oracle test");
            skipEnv = true;
            return;
        }

        vm.createSelectFork(vm.envString("HEMI_RPC_URL"));
    }

    function testPtBfBtcOraclePriceCloseToPar() public {
        if (skipEnv) {
            console2.log("Skipping testPtBfBtcOraclePriceCloseToPar");
            return;
        }

        uint8 feedDecimals = PT_BFBTC_FEED.decimals();
        (, int256 rawAnswer,,,) = PT_BFBTC_FEED.latestRoundData();

        require(feedDecimals > 0, "feed decimals zero");
        require(rawAnswer > 0, "feed returned non-positive price");

        MorphoChainlinkOracleV2 oracle = new MorphoChainlinkOracleV2(
            IERC4626(address(0)),
            1,
            PT_BFBTC_FEED,
            AggregatorV3Interface(address(0)),
            PT_BFBTC_DECIMALS,
            IERC4626(address(0)),
            1,
            AggregatorV3Interface(address(0)),
            AggregatorV3Interface(address(0)),
            HEMI_BTC_DECIMALS
        );

        uint256 price = oracle.price();
        uint256 expected = uint256(rawAnswer) *
            10 ** (36 + HEMI_BTC_DECIMALS - PT_BFBTC_DECIMALS - uint256(feedDecimals));

        console2.log("PT bfBTC/hemiBTC oracle price (1e36 scale):", price);
        console2.log("PT bfBTC/hemiBTC oracle price (1e8 scale):", price / 1e28);
        console2.log("PT bfBTC feed answer:", uint256(rawAnswer));

        assertEq(price, expected, "oracle price mismatch");
        assertApproxEqRel(price, 1e36, 0.05 ether, "PT bfBTC is not within 5% of par");
    }

    function _hasEnv(string memory key) internal view returns (bool ok) {
        try vm.envAddress(key) returns (address) {
            return true;
        } catch {}
        try vm.envString(key) returns (string memory) {
            return true;
        } catch {}
        try vm.envUint(key) returns (uint256) {
            return true;
        } catch {}
        try vm.envBool(key) returns (bool) {
            return true;
        } catch {}
        return false;
    }
}
