// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console2.sol";

import {IMorphoChainlinkOracleV2Factory} from "../src/morpho-chainlink/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {IERC4626} from "../src/morpho-chainlink/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "../src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";

interface IOracle { function price() external view returns (uint256); }
interface IERC20 { function approve(address spender, uint256 amount) external returns (bool); }
interface IMorpho {
    struct MarketParams { address loanToken; address collateralToken; address oracle; address irm; uint256 lltv; }
    function owner() external view returns (address);
    function enableIrm(address irm) external;
    function enableLltv(uint256 lltv) external;
    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256,uint256);
    function supplyCollateral(MarketParams memory marketParams, uint256 collateral, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256,uint256);
}

contract PTSlvlUSD_USDC_OracleFactory_EthereumTest is Test {
    // Ethereum mainnet fork
    uint256 constant ETH_CHAIN_ID = 1;

    // Config from .env snippet (Ethereum mainnet)
    address constant FACTORY = 0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766;
    // PT-slvlUSD-18JAN2026/USD feed (base)
    AggregatorV3Interface constant BASE_FEED_1 = AggregatorV3Interface(0x0718626b2F7d8Fe2f73BBaE31Ae290b859046349);
    // USDC/USD feed (quote)
    AggregatorV3Interface constant QUOTE_FEED_1 = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);

    uint256 constant BASE_TOKEN_DECIMALS = 18; // PT token decimals
    uint256 constant QUOTE_TOKEN_DECIMALS = 6; // USDC decimals

    // Morpho Blue + IRM on Ethereum mainnet (set to known deployments)
    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb; // Example: Morpho Blue mainnet
    address constant IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;        // IRM on Ethereum mainnet

    uint256 constant LLTV_915 = 915_000_000_000_000_000; // 91.5%

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        require(block.chainid == ETH_CHAIN_ID, "not on Ethereum");
    }

    function _deployOracle() internal returns (address oracle) {
        IMorphoChainlinkOracleV2Factory f = IMorphoChainlinkOracleV2Factory(FACTORY);
        bytes32 salt = keccak256(abi.encodePacked("PT-slvlUSD/USD", block.number));
        oracle = address(
            f.createMorphoChainlinkOracleV2(
                IERC4626(address(0)), // base vault omitted
                1,                    // base sample must be 1 when no vault
                BASE_FEED_1,          // PT-slvlUSD/USD
                AggregatorV3Interface(address(0)), // base feed2 omitted
                BASE_TOKEN_DECIMALS,  // base token decimals (PT: 18)
                IERC4626(address(0)), // quote vault omitted
                1,                    // quote sample must be 1 when no vault
                QUOTE_FEED_1,         // USDC/USD
                AggregatorV3Interface(address(0)), // quote feed2 omitted
                QUOTE_TOKEN_DECIMALS, // USDC: 6
                salt
            )
        );
        assertTrue(f.isMorphoChainlinkOracleV2(oracle), "factory did not recognize oracle");
    }

    function testDeployOracle_PTSlvlUSD_USDC() public {
        address oracle = _deployOracle();
        console2.log("Oracle deployed:", oracle);
    }

    function testOraclePriceMatchesFeeds_PTSlvlUSD_USDC() public {
        address oracle = _deployOracle();

        // Fetch feed answers and decimals
        (, int256 baseAnswer,,,) = BASE_FEED_1.latestRoundData();
        uint8 baseFeedDecimals = BASE_FEED_1.decimals();
        (, int256 quoteAnswer,,,) = QUOTE_FEED_1.latestRoundData();
        uint8 quoteFeedDecimals = QUOTE_FEED_1.decimals();

        // SCALE_FACTOR exponent: 36 + dQ + fpQ1 - dB - fpB1 (feed2s omitted)
        uint256 exp = 36 + QUOTE_TOKEN_DECIMALS + uint256(quoteFeedDecimals)
            - BASE_TOKEN_DECIMALS - uint256(baseFeedDecimals);
        uint256 scaleFactor = 10 ** exp; // qCS/bCS = 1/1

        // Expected price = SCALE_FACTOR * baseFeed1 / quoteFeed1
        // baseAnswer, quoteAnswer are non-negative per ChainlinkDataFeedLib
        uint256 expected = (uint256(baseAnswer) * scaleFactor) / uint256(quoteAnswer);
        uint256 actual = IOracle(oracle).price();

        console2.log("Base feed (PT/USD) answer:", uint256(baseAnswer));
        console2.log("Base feed decimals:", baseFeedDecimals);
        console2.log("Quote feed (USDC/USD) answer:", uint256(quoteAnswer));
        console2.log("Quote feed decimals:", quoteFeedDecimals);
        console2.log("Scale factor (10^exp) exp:", exp);
        console2.log("Expected (1e36 scaled):", expected);
        console2.log("Actual   (1e36 scaled):", actual);

        // Allow tiny tolerance
        assertApproxEqRel(actual, expected, 1e8);
    }

    function testMarketDeployAndBorrowBounds_PTSlvlUSD_USDC() public {
        address oracle = _deployOracle();

        // Create the market on Ethereum
        IMorpho morpho = IMorpho(MORPHO_BLUE);
        IMorpho.MarketParams memory params = IMorpho.MarketParams({
            loanToken: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // USDC mainnet
            collateralToken: address(0x9eBb9230276e858eFb8209618055ADD25a2bf41B), // PT-slvlUSD-18JAN2026 token
            oracle: oracle,
            irm: IRM,
            lltv: LLTV_915
        });
        morpho.createMarket(params);

        address user = address(0xBEEF);
        uint256 collateralAmount = 1e21; // 1,000 PT units assuming 18 decimals
        uint256 supplyUsdc = 2_000 * 1e6; // 2,000 USDC liquidity

        // Fund user with tokens on fork
        deal(params.collateralToken, user, collateralAmount);
        deal(params.loanToken, user, supplyUsdc);

        // Supply collateral and USDC liquidity
        vm.startPrank(user);
        IERC20(params.collateralToken).approve(MORPHO_BLUE, collateralAmount);
        morpho.supplyCollateral(params, collateralAmount, user, "");
        IERC20(params.loanToken).approve(MORPHO_BLUE, supplyUsdc);
        morpho.supply(params, supplyUsdc, 0, user, "");
        vm.stopPrank();

        // Compute cap from oracle
        uint256 oraclePrice = IOracle(oracle).price(); // 1e36 scaled PT/USDC
        uint256 maxBorrow = collateralAmount * oraclePrice / 1e36; // USDC (6 decimals)
        maxBorrow = maxBorrow * LLTV_915 / 1e18;

        // Borrow below cap: should succeed
        uint256 borrowOk = (maxBorrow * 95) / 100;
        vm.prank(user);
        morpho.borrow(params, borrowOk, 0, user, user);

        // Borrow above cap: should revert
        uint256 borrowTooMuch = maxBorrow + 1;
        vm.expectRevert();
        vm.prank(user);
        morpho.borrow(params, borrowTooMuch, 0, user, user);
    }
}

