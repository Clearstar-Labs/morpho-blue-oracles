// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";
import {IMorpho as MorphoExt, Id, MarketParams as Mkt} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IOracle} from "../lib/morpho-blue/src/interfaces/IOracle.sol";
import "../scripts/DeployMorphoMarket.s.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract HemiLltvBorrowTest is Test {
    function _hasEnv(string memory key) internal view returns (bool ok) {
        try vm.envAddress(key) returns (address) { return true; } catch {}
        try vm.envUint(key) returns (uint256) { return true; } catch {}
        try vm.envString(key) returns (string memory) { return true; } catch {}
        return false;
    }

    function _marketId(Mkt memory p) internal pure returns (Id) {
        return Id.wrap(keccak256(abi.encode(p)));
    }

    function testBorrowWithinAndOutsideLLTV() public {
        if (!_hasEnv("HEMI_RPC_URL")) {
            console2.log("HEMI_RPC_URL not set; skipping LLTV test");
            return;
        }
        vm.createSelectFork(vm.envString("HEMI_RPC_URL"));

        // Ensure env is configured
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
                console2.log("Skipping");
                return;
            }
        }

        address MORPHO = vm.envAddress("MORPHO_CONTRACT");
        address LOAN = vm.envAddress("LOAN_TOKEN");
        address COLL = vm.envAddress("COLLATERAL_TOKEN");
        address ORACLE = vm.envAddress("ORACLE_ADDRESS");
        uint256 LLTV = vm.envUint("LLTV");

        // Ensure market exists (create it via script if needed)
        Mkt memory mp = Mkt({
            loanToken: LOAN,
            collateralToken: COLL,
            oracle: ORACLE,
            irm: vm.envAddress("IRM_ADDRESS"),
            lltv: LLTV
        });
        Id id = _marketId(mp);
        MorphoExt morpho = MorphoExt(MORPHO);
        // If not created, run the script without broadcast to add mapping
        Mkt memory got = morpho.idToMarketParams(id);
        if (got.loanToken == address(0) || got.oracle == address(0)) {
            vm.setEnv("SCRIPT_BROADCAST", "false");
            DeployMorphoMarket script = new DeployMorphoMarket();
            script.run();
        }

        // Price and decimals
        uint256 price = IOracle(ORACLE).price(); // 1e36-scaled
        uint8 dLoan = IERC20(LOAN).decimals();
        uint8 dColl = IERC20(COLL).decimals();
        console2.log("Oracle price (1e36):", price);
        console2.log("Loan decimals:", dLoan);
        console2.log("Coll decimals:", dColl);

        // Seed liquidity and collateral via deal (cheatcode)
        // Collateral: 1 unit (10^dec)
        uint256 collateralUnits = 10 ** uint256(dColl);
        // Max borrow in loan units: collateral * price * lltv / 1e36 / 1e18
        uint256 maxBorrow = (collateralUnits * price * LLTV) / (1e36 * 1e18);
        // Supply at least 2x max borrow liquidity
        uint256 seedLiquidity = maxBorrow * 2 + (10 ** uint256(dLoan));

        deal(LOAN, address(this), seedLiquidity);
        deal(COLL, address(this), collateralUnits);

        // Approvals
        IERC20(LOAN).approve(MORPHO, type(uint256).max);
        IERC20(COLL).approve(MORPHO, type(uint256).max);

        // Supply loan token liquidity
        morpho.supply(mp, seedLiquidity, 0, address(this), "");

        // Supply collateral
        morpho.supplyCollateral(mp, collateralUnits, address(this), "");

        // Borrow within LLTV (1 wei under max)
        uint256 borrowWithin = maxBorrow > 0 ? (maxBorrow - 1) : 0;
        (uint256 assetsBorrowedWithin,) = morpho.borrow(mp, borrowWithin, 0, address(this), address(this));
        assertEq(assetsBorrowedWithin, borrowWithin, "borrow within should succeed");

        // Attempt to borrow beyond LLTV (push total over max)
        uint256 remainingCapacity = maxBorrow - borrowWithin;
        uint256 borrowBeyond = remainingCapacity + 1; // 1 unit above allowed
        vm.expectRevert();
        morpho.borrow(mp, borrowBeyond, 0, address(this), address(this));
    }
}
