// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/Constants.sol";
import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import {MorphoChainlinkOracleV2} from "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import "../src/fxusd-nav-adapter/NetAssetValueChainlinkAdapter.sol";

contract NetAssetValueChainlinkAdapterTest is Test {
    INetAssetValue internal constant fxUSD = INetAssetValue(0x7743e50F534a7f9F1791DdE7dCD89F7783Eefc39);

    NetAssetValueChainlinkAdapter internal adapter;
    MorphoChainlinkOracleV2 internal morphoOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        require(block.chainid == 1, "chain isn't Ethereum");
        adapter = new NetAssetValueChainlinkAdapter(fxUSD);
        morphoOracle = new MorphoChainlinkOracleV2(
            vaultZero, 1, AggregatorV3Interface(address(adapter)), feedZero, 18, vaultZero, 1, feedZero, feedZero, 18
        );
    }

    function testDecimals() public {
        assertEq(adapter.decimals(), uint8(18));
    }

    function testDescription() public {
        assertEq(adapter.description(), "Net Asset Value in USD");
    }

    function testLatestRoundData() public {
        console.log("Testing latestRoundData");
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            adapter.latestRoundData();
        console2.log("Answer from adapter:", uint256(answer));
        assertEq(roundId, 0);
        assertEq(uint256(answer), fxUSD.nav());
        console2.log("fxUSD.nav():", fxUSD.nav());
        assertEq(startedAt, 0);
        assertEq(updatedAt, 0);
        assertEq(answeredInRound, 0);
    }

    function testOracleFxUSDNav() public {
        (, int256 expectedPrice,,,) = adapter.latestRoundData();
        assertEq(morphoOracle.price(), uint256(expectedPrice) * 10 ** (36 + 18 - 18 - 18));
    }
}
