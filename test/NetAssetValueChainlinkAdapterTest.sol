// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/Constants.sol";
import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import {MorphoChainlinkOracleV2} from "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import "../src/fxusd-nav-adapter/NetAssetValueChainlinkAdapter.sol";

contract NetAssetValueChainlinkAdapterTest is Test {
    INetAssetValue internal constant fxToken = INetAssetValue(0x7743e50F534a7f9F1791DdE7dCD89F7783Eefc39);

    NetAssetValueChainlinkAdapter internal adapter;
    MorphoChainlinkOracleV2 internal morphoOracle;
    uint256 internal maxCap;
    address internal admin = address(1);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        require(block.chainid == 1, "chain isn't Ethereum");
        
        // Get the current NAV and set maxCap to 1.5x that value (the maximum allowed)
        uint256 currentNav = fxToken.nav();
        maxCap = currentNav * 3 / 2;
        console2.log("Current NAV:", currentNav);
        console2.log("Max Cap:", maxCap);
        
        adapter = new NetAssetValueChainlinkAdapter(fxToken, maxCap, admin);
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
        console2.log("Testing latestRoundData");
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            adapter.latestRoundData();
        console2.log("Answer from adapter:", uint256(answer));
        assertEq(roundId, 0);
        assertEq(uint256(answer), fxToken.nav());
        console2.log("fxToken.nav():", fxToken.nav());
        assertEq(startedAt, 0);
        assertEq(updatedAt, 0);
        assertEq(answeredInRound, 0);
    }

    function testOraclefxTokenNav() public {
        (, int256 expectedPrice,,,) = adapter.latestRoundData();
        assertEq(morphoOracle.price(), uint256(expectedPrice) * 10 ** (36 + 18 - 18 - 18));
    }

    function testMaxCapTooHigh() public {
        // Get the current NAV
        uint256 currentNav = fxToken.nav();
        
        // Try to set maxCap to more than 1.5x the current NAV (which should fail)
        uint256 tooHighMaxCap = currentNav * 3 / 2 + 1;
        
        console2.log("Current NAV:", currentNav);
        console2.log("Too high max cap:", tooHighMaxCap);
        
        vm.expectRevert("Max cap too high");
        new NetAssetValueChainlinkAdapter(fxToken, tooHighMaxCap, admin);
    }
    
    function testMaxCapTooLow() public {
        // Get the current NAV
        uint256 currentNav = fxToken.nav();
        
        // Try to set maxCap below the minimum threshold (which should fail)
        uint256 tooLowMaxCap = currentNav * 105 / 100 - 1;
        
        console2.log("Current NAV:", currentNav);
        console2.log("Too low max cap:", tooLowMaxCap);
        
        vm.expectRevert("Max cap too low");
        new NetAssetValueChainlinkAdapter(fxToken, tooLowMaxCap, admin);
    }
    
    // Add tests for the timelock functionality
    function testProposeAndApplyMaxCap() public {
        uint256 currentNav = fxToken.nav();
        uint256 newMaxCap = currentNav * 4 / 3; // 133% of current NAV
        
        // Only admin can propose
        vm.prank(address(2));
        vm.expectRevert("Only admin can propose");
        adapter.proposeMaxCap(newMaxCap);
        
        // Admin proposes new max cap
        vm.prank(admin);
        adapter.proposeMaxCap(newMaxCap);
        
        assertEq(adapter.proposedMaxCap(), newMaxCap);
        assertEq(adapter.proposedMaxCapTimestamp(), block.timestamp + 2 days);
        
        // Cannot apply before timelock expires
        vm.expectRevert("Timelock not expired");
        adapter.applyMaxCap();
        
        // Warp to after timelock period
        vm.warp(block.timestamp + 2 days + 1);
        
        // Apply the new max cap
        adapter.applyMaxCap();
        
        // Verify the max cap was updated
        assertEq(adapter.maxCap(), newMaxCap);
        assertEq(adapter.proposedMaxCap(), 0);
        assertEq(adapter.proposedMaxCapTimestamp(), 0);
    }
    
    function testProposeMaxCapTooHigh() public {
        uint256 currentNav = fxToken.nav();
        uint256 tooHighMaxCap = currentNav * 3 / 2 + 1; // Just above the 150% limit
        
        vm.prank(admin);
        vm.expectRevert("Max cap too high");
        adapter.proposeMaxCap(tooHighMaxCap);
    }
    
    function testProposeMaxCapTooLow() public {
        uint256 currentNav = fxToken.nav();
        uint256 tooLowMaxCap = currentNav * 105 / 100 - 1; // Just below the 105% limit
        
        vm.prank(admin);
        vm.expectRevert("Max cap too low");
        adapter.proposeMaxCap(tooLowMaxCap);
    }
}
