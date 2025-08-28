// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import {IMorphoChainlinkOracleV2Factory} from "../src/morpho-chainlink/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {IERC4626} from "../src/morpho-chainlink/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "../src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";
import {MorphoChainlinkOracleV2} from "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";

interface IERC20 { function approve(address spender, uint256 amount) external returns (bool); function balanceOf(address) external view returns (uint256); }

interface IOracle { function price() external view returns (uint256); }

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function position(MarketParams memory marketParams, address user) external view returns (uint256,uint128,uint128);
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256,uint256);
    function supplyCollateral(MarketParams memory marketParams, uint256 collateral, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256,uint256);
}

contract YusdUsdc_OracleFactory_MarketTest is Test {
    // Base chain IDs and addresses
    uint256 constant BASE_CHAIN_ID = 8453;

    // Addresses on Base mainnet
    address constant FACTORY = 0x2DC205F24BCb6B311E5cdf0745B0741648Aebd3d; // MorphoChainlinkOracleV2Factory
    IERC4626 constant YUSD_VAULT = IERC4626(0x4772D2e014F9fC3a820C444e3313968e9a5C8121); // yUSD (ERC4626)
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // Morpho Blue
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687; // Example IRM on Base

    uint256 constant LLTV_915 = 915_000_000_000_000_000; // 91.5%

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        require(block.chainid == BASE_CHAIN_ID, "not on Base");
    }

    function _marketId(IMorpho.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function _deployOracle() internal returns (address oracle, AggregatorV3Interface baseFeed1, uint256 baseTokenDecimals, uint256 quoteTokenDecimals) {
        // Configure oracle params for yUSD priced in USDC using a direct base feed (no vault conversion path)
        uint256 baseSample = 1; // must be 1 when baseVault is address(0)
        AggregatorV3Interface feedZero = AggregatorV3Interface(address(0));
        baseFeed1 = AggregatorV3Interface(0xAd5771b3C984748fd39566d4B58Cd32ec4B91856);
        baseTokenDecimals = 18;
        quoteTokenDecimals = 6;

        IMorphoChainlinkOracleV2Factory f = IMorphoChainlinkOracleV2Factory(FACTORY);
        bytes32 salt = keccak256(abi.encodePacked("YUSD/USDC", block.number));
        oracle = address(
            f.createMorphoChainlinkOracleV2(
                IERC4626(address(0)),
                baseSample,
                baseFeed1,
                feedZero,
                baseTokenDecimals,
                IERC4626(address(0)),
                1,
                feedZero,
                feedZero,
                quoteTokenDecimals,
                salt
            )
        );
        assertTrue(f.isMorphoChainlinkOracleV2(oracle), "factory did not recognize oracle");
    }

    function _deployMarket(address oracle) internal returns (IMorpho.MarketParams memory params, bytes32 marketId) {
        params = IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: address(YUSD_VAULT),
            oracle: oracle,
            irm: IRM,
            lltv: LLTV_915
        });
        IMorpho morpho = IMorpho(MORPHO_BLUE);
        marketId = _marketId(params);
        morpho.createMarket(params);
        IMorpho.MarketParams memory created = morpho.idToMarketParams(marketId);
        assertEq(created.loanToken, params.loanToken, "loan token mismatch");
        assertEq(created.collateralToken, params.collateralToken, "collateral token mismatch");
        assertEq(created.oracle, params.oracle, "oracle mismatch");
        assertEq(created.irm, params.irm, "irm mismatch");
        assertEq(created.lltv, params.lltv, "lltv mismatch");
    }

    function testOracleOnly_YUSD_USDC() public {
        (address oracle, AggregatorV3Interface baseFeed1, uint256 bDec, uint256 qDec) = _deployOracle();
        (, int256 feedAnswer,,,) = baseFeed1.latestRoundData();
        uint8 feedDecimals = baseFeed1.decimals();
        uint256 expected = (10 ** (36 + qDec - bDec - feedDecimals)) * uint256(feedAnswer);
        uint256 actual = IOracle(oracle).price();
        console2.log("baseFeed1 answer:", uint256(feedAnswer));
        console2.log("baseFeed1 decimals:", feedDecimals);
        console2.log("Expected (1e36 scaled):", expected);
        console2.log("Actual   (1e36 scaled):", actual);
        assertApproxEqRel(actual, expected, 1e8);
    }

    function testMarketOnly_YUSD_USDC() public {
        (address oracle,,,) = _deployOracle();
        (IMorpho.MarketParams memory params, bytes32 marketId) = _deployMarket(oracle);
        console2.log("Market created:", vm.toString(marketId));
        console2.log("Oracle:", oracle);
    }

    function testSupplyAndBorrowFlow_YUSD_USDC() public {
        (address oracle,,,) = _deployOracle();
        (IMorpho.MarketParams memory params,) = _deployMarket(oracle);
        IMorpho morpho = IMorpho(MORPHO_BLUE);

        address user = address(0xBEEF);
        // Choose larger amounts to avoid truncation: ~1,000 USDC cap
        uint256 collateralAmount = 1e21; // 1,000 yUSD (shares) approx in terms of USDC cap
        uint256 supplyUsdc = 2_000 * 1e6; // 2,000 USDC liquidity

        // Give the user balances on fork
        deal(address(YUSD_VAULT), user, collateralAmount);
        deal(USDC, user, supplyUsdc);

        vm.startPrank(user);
        IERC20(address(YUSD_VAULT)).approve(MORPHO_BLUE, collateralAmount);
        morpho.supplyCollateral(params, collateralAmount, user, "");

        IERC20(USDC).approve(MORPHO_BLUE, supplyUsdc);
        morpho.supply(params, supplyUsdc, 0, user, "");
        vm.stopPrank();

        uint256 oraclePrice = IOracle(oracle).price();
        uint256 maxBorrow = collateralAmount * oraclePrice / 1e36; // USDC units (6 decimals)
        maxBorrow = maxBorrow * LLTV_915 / 1e18; // apply LLTV

        // Borrow slightly below the max -> should succeed
        uint256 borrowOk = (maxBorrow * 95) / 100; // 95% of cap
        vm.prank(user);
        morpho.borrow(params, borrowOk, 0, user, user);

        // Borrow above the cap -> should revert
        uint256 borrowTooMuch = maxBorrow + 1;
        vm.expectRevert();
        vm.prank(user);
        morpho.borrow(params, borrowTooMuch, 0, user, user);
    }
}


