// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Minimal Morpho Blue interface used by this script
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32 id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);
}

interface IOracle { function price() external view returns (uint256); }

contract BorrowMaxMorphoLoanToken is Script {
    function getMarketParams() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: vm.envAddress("LOAN_TOKEN"),
            collateralToken: vm.envAddress("COLLATERAL_TOKEN"),
            oracle: vm.envAddress("ORACLE_ADDRESS"),
            irm: vm.envAddress("IRM_ADDRESS"),
            lltv: vm.envUint("LLTV")
        });
    }

    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }

    function _toBorrowAssets(
        uint128 userBorrowShares,
        uint128 totalBorrowAssets,
        uint128 totalBorrowShares
    ) internal pure returns (uint256) {
        if (userBorrowShares == 0 || totalBorrowShares == 0) return 0;
        // shares * totalAssets / totalShares
        return (uint256(userBorrowShares) * uint256(totalBorrowAssets)) / uint256(totalBorrowShares);
    }

    function run() external {
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");

        // Sender/user
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address user = vm.addr(pk);

        // Params and IDs
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        // Read position and market state
        IMorpho morpho = IMorpho(morphoContract);
        (
            uint256 supplyShares,
            uint128 borrowShares,
            uint128 collateral
        ) = morpho.position(marketId, user);

        (
            uint128 totalSupplyAssets,
            ,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            ,
            
        ) = morpho.market(marketId);

        // Oracle price and LLTV
        uint256 oraclePrice = IOracle(marketParams.oracle).price(); // 1e36 scaled
        uint256 lltv = marketParams.lltv; // 1e18 scaled

        // Max borrow in loan token units allowed by LLTV
        // price is Q/B scaled 1e36; collateral is base atomic units.
        // allowedBorrow = collateral * price * lltv / (1e36 * 1e18)
        uint256 maxAllowed = (uint256(collateral) * oraclePrice * lltv) / (1e36 * 1e18);

        // Current borrowed in assets
        uint256 currentDebtAssets = _toBorrowAssets(borrowShares, totalBorrowAssets, totalBorrowShares);

        // Headroom left by LLTV (in loan token assets)
        uint256 headroom = maxAllowed > currentDebtAssets ? (maxAllowed - currentDebtAssets) : 0;

        // Market available liquidity = totalSupplyAssets - totalBorrowAssets
        uint256 availableLiquidity = 0;
        if (totalSupplyAssets > totalBorrowAssets) {
            availableLiquidity = uint256(totalSupplyAssets) - uint256(totalBorrowAssets);
        }

        // Optional percentage headroom usage in basis points (default 100%)
        uint256 headroomBps;
        try vm.envUint("BORROW_HEADROOM_BPS") returns (uint256 bps) {
            headroomBps = bps;
        } catch {
            headroomBps = 10_000; // 100%
        }
        if (headroomBps > 10_000) headroomBps = 10_000;

        uint256 targetHeadroom = (headroom * headroomBps) / 10_000;

        // Borrow amount is the minimum of target headroom and market available liquidity
        uint256 borrowAmount = targetHeadroom < availableLiquidity ? targetHeadroom : availableLiquidity;

        // Optional safety buffer (e.g., 0.1%) to avoid rounding edge cases
        if (borrowAmount > 0) {
            borrowAmount = (borrowAmount * 999) / 1000;
        }

        // Display info
        console2.log("=== Borrow Max Loan Token from Morpho Market ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Morpho:", morphoContract);
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("User:", user);
        console2.log("Collateral (atomic):", collateral);
        console2.log("Oracle price (1e36):", oraclePrice);
        console2.log("LLTV (1e18):", lltv);
        console2.log("Current debt (assets):", currentDebtAssets);
        console2.log("Max allowed (assets):", maxAllowed);
        console2.log("Headroom (assets):", headroom);
        console2.log("Headroom used (bps):", headroomBps);
        console2.log("Target headroom (assets):", targetHeadroom);
        console2.log("Market available liquidity (assets):", availableLiquidity);
        console2.log("Planned borrow amount (assets):", borrowAmount);

        require(borrowAmount > 0, "No borrowable amount (headroom or liquidity zero)");

        // Execute borrow
        vm.startBroadcast(pk);
        try morpho.borrow(marketParams, borrowAmount, 0, user, user) returns (uint256 assetsBorrowed, uint256 sharesBorrowed) {
            console2.log("Borrowed assets:", assetsBorrowed);
            console2.log("Borrow shares:", sharesBorrowed);
        } catch Error(string memory reason) {
            console2.log("Borrow failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Borrow failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Borrow failed");
        }
        vm.stopBroadcast();

        // Post-borrow position
        (, uint128 borrowSharesAfter, uint128 collateralAfter) = morpho.position(marketId, user);
        console2.log("Borrow shares after:", borrowSharesAfter);
        console2.log("Collateral after:", collateralAfter);
    }
}
