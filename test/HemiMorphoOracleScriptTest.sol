// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../scripts/DeployMorphoChainlinkOracleV2.s.sol";

contract HemiMorphoOracleScriptTest is Test {
    function _hasEnv(string memory key) internal view returns (bool ok) {
        // Try address then string, tolerate failures
        try vm.envAddress(key) returns (address) { return true; } catch {}
        try vm.envString(key) returns (string memory) { return true; } catch {}
        try vm.envUint(key) returns (uint256) { return true; } catch {}
        try vm.envBool(key) returns (bool) { return true; } catch {}
        return false;
    }

    function testDeployHemiBtcUsdcEOracleAndLogPrice() public {
        // Require Hemi fork
        if (!_hasEnv("HEMI_RPC_URL")) {
            console2.log("HEMI_RPC_URL not set; skipping test");
            return;
        }
        vm.createSelectFork(vm.envString("HEMI_RPC_URL"));

        // Ensure required env vars exist; otherwise skip to avoid false failures
        string[5] memory must = [
            string("MORPHO_CHAINLINK_ORACLE_V2_FACTORY"),
            string("BASE_FEED_1"),
            string("QUOTE_FEED_1"),
            string("BASE_TOKEN_DECIMALS"),
            string("QUOTE_TOKEN_DECIMALS")
        ];

        for (uint256 i = 0; i < must.length; i++) {
            if (!_hasEnv(must[i])) {
                console2.log("Missing env:", must[i]);
                console2.log("Skipping: configure .env for hemiBTC/USD and USDC.e/USD feeds");
                return;
            }
        }

        // Force non-vault path and disable broadcast inside script for the test
        vm.setEnv("BASE_VAULT", "0x0000000000000000000000000000000000000000");
        vm.setEnv("BASE_VAULT_CONVERSION_SAMPLE", "1");
        vm.setEnv("QUOTE_VAULT", "0x0000000000000000000000000000000000000000");
        vm.setEnv("QUOTE_VAULT_CONVERSION_SAMPLE", "1");
        vm.setEnv("SCRIPT_BROADCAST", "false");
        // Provide a static salt for determinism within this test run
        vm.setEnv(
            "SALT",
            "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        );

        // Call the script using .env
        DeployMorphoChainlinkOracleV2 script = new DeployMorphoChainlinkOracleV2();
        script.run();

        address oracle = script.latestOracle();
        console2.log("Oracle deployed at:", oracle);
        require(oracle != address(0), "oracle not deployed");

        uint256 p = IOracle(oracle).price();
        console2.log("hemiBTC/USDC.e price (1e36 scale):", p);
        assertGt(p, 0, "oracle price is zero");
    }
}
