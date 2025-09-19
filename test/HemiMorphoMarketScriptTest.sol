// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import "../scripts/DeployMorphoMarket.s.sol";

contract HemiMorphoMarketScriptTest is Test {
    function _hasEnv(string memory key) internal view returns (bool ok) {
        // Probe various types to detect presence
        try vm.envAddress(key) returns (address) { return true; } catch {}
        try vm.envUint(key) returns (uint256) { return true; } catch {}
        try vm.envString(key) returns (string memory) { return true; } catch {}
        return false;
    }

    function _marketId(IMorpho.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function testDeployHemiBtcUsdcEMarketWithScript() public {
        if (!_hasEnv("HEMI_RPC_URL")) {
            console2.log("HEMI_RPC_URL not set; skipping market deploy test");
            return;
        }
        vm.createSelectFork(vm.envString("HEMI_RPC_URL"));

        // Required env for script
        string[6] memory must = [
            string("MORPHO_CONTRACT"),
            string("LOAN_TOKEN"),
            string("COLLATERAL_TOKEN"),
            string("ORACLE_ADDRESS"),
            string("IRM_ADDRESS"),
            string("LLTV")
        ];
        for (uint256 i = 0; i < must.length; i++) {
            if (!_hasEnv(must[i])) {
                console2.log("Missing env:", must[i]);
                console2.log("Skipping: configure .env for hemiBTC/USDC.e market");
                return;
            }
        }

        // Disable script broadcast, execute as a normal call on the fork
        vm.setEnv("SCRIPT_BROADCAST", "false");
        // Run the market deploy script (state changes occur on the fork)
        DeployMorphoMarket script = new DeployMorphoMarket();
        script.run();

        // Build market params from env to compute id and verify
        IMorpho.MarketParams memory mp = IMorpho.MarketParams({
            loanToken: vm.envAddress("LOAN_TOKEN"),
            collateralToken: vm.envAddress("COLLATERAL_TOKEN"),
            oracle: vm.envAddress("ORACLE_ADDRESS"),
            irm: vm.envAddress("IRM_ADDRESS"),
            lltv: vm.envUint("LLTV")
        });
        bytes32 id = _marketId(mp);

        address morpho = vm.envAddress("MORPHO_CONTRACT");
        IMorpho M = IMorpho(morpho);
        IMorpho.MarketParams memory got = M.idToMarketParams(id);

        // Assertions
        assertEq(got.loanToken, mp.loanToken, "loan token mismatch");
        assertEq(got.collateralToken, mp.collateralToken, "collateral token mismatch");
        assertEq(got.oracle, mp.oracle, "oracle mismatch");
        assertEq(got.irm, mp.irm, "irm mismatch");
        assertEq(got.lltv, mp.lltv, "lltv mismatch");

        // Logs
        console2.log("Market created for hemiBTC/USDC.e");
        console2.log("Market ID:", vm.toString(id));
        console2.log("Morpho:", morpho);
        console2.log("LoanToken:", mp.loanToken);
        console2.log("CollateralToken:", mp.collateralToken);
        console2.log("Oracle:", mp.oracle);
        console2.log("IRM:", mp.irm);
        console2.log("LLTV:", mp.lltv);
    }
}
