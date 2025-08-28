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
    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes calldata data) external returns (uint256,uint256);
    function supplyCollateral(MarketParams memory marketParams, uint256 collateral, address onBehalf, bytes calldata data) external;
    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256,uint256);
}

contract PTxUSD_USDC_OracleFactory_EthereumTest is Test {
    // Ethereum mainnet fork
    uint256 constant ETH_CHAIN_ID = 1;

    // Addresses (EIP-55 checksummed)
    address constant FACTORY = 0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766;
    AggregatorV3Interface constant BASE_FEED_1 = AggregatorV3Interface(0x934899674A352935053FBEc771defd3008306db4); // PT-xUSD/USD
    AggregatorV3Interface constant QUOTE_FEED_1 = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6); // USDC/USD (8 dec)

    // Token decimals per provided env
    uint256 constant BASE_TOKEN_DECIMALS = 6;
    uint256 constant QUOTE_TOKEN_DECIMALS = 6;

    // From env for market deploy
    address MORPHO_BLUE;
    address LOAN_TOKEN;
    address COLLATERAL_TOKEN;
    address IRM;
    uint256 LLTV;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        require(block.chainid == ETH_CHAIN_ID, "not on Ethereum");

        // Read market params from env (as requested)
        MORPHO_BLUE = vm.envAddress("MORPHO_CONTRACT");
        LOAN_TOKEN = vm.envAddress("LOAN_TOKEN");
        COLLATERAL_TOKEN = vm.envAddress("COLLATERAL_TOKEN");
        IRM = vm.envAddress("IRM_ADDRESS");
        LLTV = vm.envUint("LLTV");
    }

    function _deployOracle() internal returns (address oracle) {
        IMorphoChainlinkOracleV2Factory f = IMorphoChainlinkOracleV2Factory(FACTORY);
        bytes32 salt = keccak256(abi.encodePacked("PT-xUSD/USDC", block.number));
        oracle = address(
            f.createMorphoChainlinkOracleV2(
                IERC4626(address(0)), // base vault omitted
                1,                    // base sample must be 1 when no vault
                BASE_FEED_1,          // PT-xUSD/USD
                AggregatorV3Interface(address(0)), // base feed2 omitted
                BASE_TOKEN_DECIMALS,  // base token decimals (per env)
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

    function _marketId(IMorpho.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function testDeployOracle_PTxUSD_USDC() public {
        address oracle = _deployOracle();
        console2.log("Oracle deployed:", oracle);
    }

    function testOraclePriceMatchesFeeds_PTxUSD_USDC() public {
        address oracle = _deployOracle();

        (, int256 baseAnswer,,,) = BASE_FEED_1.latestRoundData();
        uint8 baseFeedDecimals = BASE_FEED_1.decimals();
        (, int256 quoteAnswer,,,) = QUOTE_FEED_1.latestRoundData();
        uint8 quoteFeedDecimals = QUOTE_FEED_1.decimals();

        uint256 exp = 36 + QUOTE_TOKEN_DECIMALS + uint256(quoteFeedDecimals)
            - BASE_TOKEN_DECIMALS - uint256(baseFeedDecimals);
        uint256 scaleFactor = 10 ** exp; // qCS/bCS = 1/1
        uint256 expected = (uint256(baseAnswer) * scaleFactor) / uint256(quoteAnswer);
        uint256 actual = IOracle(oracle).price();

        console2.log("Base feed (PT-xUSD/USD) answer:", uint256(baseAnswer));
        console2.log("Base feed decimals:", baseFeedDecimals);
        console2.log("Quote feed (USDC/USD) answer:", uint256(quoteAnswer));
        console2.log("Quote feed decimals:", quoteFeedDecimals);
        console2.log("Scale factor exp:", exp);
        console2.log("Expected (1e36 scaled):", expected);
        console2.log("Actual   (1e36 scaled):", actual);
        assertApproxEqRel(actual, expected, 1e8);
    }

    function testMarketDeployAndBorrowBounds_PTxUSD_USDC() public {
        address oracle = _deployOracle();

        IMorpho.MarketParams memory params = IMorpho.MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: oracle,
            irm: IRM,
            lltv: LLTV
        });

        IMorpho morpho = IMorpho(MORPHO_BLUE);
        bytes32 id = _marketId(params);
        morpho.createMarket(params);
        IMorpho.MarketParams memory created = morpho.idToMarketParams(id);
        assertEq(created.loanToken, params.loanToken, "loan token mismatch");
        assertEq(created.collateralToken, params.collateralToken, "collateral token mismatch");
        assertEq(created.oracle, params.oracle, "oracle mismatch");
        assertEq(created.irm, params.irm, "irm mismatch");
        assertEq(created.lltv, params.lltv, "lltv mismatch");

        // Supply user balances
        address user = address(0xBEEF);
        uint256 collateralAmount = vm.envOr("SUPPLY_AMOUNT", uint256(1_000_000)); // default 1e6
        uint256 supplyUsdc = vm.envOr("SUPPLY_AMOUNT", uint256(1_000_000));
        deal(COLLATERAL_TOKEN, user, collateralAmount);
        deal(LOAN_TOKEN, user, supplyUsdc);

        vm.startPrank(user);
        IERC20(COLLATERAL_TOKEN).approve(MORPHO_BLUE, collateralAmount);
        morpho.supplyCollateral(params, collateralAmount, user, "");
        IERC20(LOAN_TOKEN).approve(MORPHO_BLUE, supplyUsdc);
        morpho.supply(params, supplyUsdc, 0, user, "");
        vm.stopPrank();

        uint256 oraclePrice = IOracle(oracle).price(); // 1e36 scaled PT/USDC
        uint256 maxBorrow = collateralAmount * oraclePrice / 1e36; // USDC units (6 dec)
        maxBorrow = maxBorrow * LLTV / 1e18; // apply LLTV

        uint256 borrowOk = (maxBorrow * 95) / 100; // 95% of cap
        vm.prank(user);
        morpho.borrow(params, borrowOk, 0, user, user);

        uint256 borrowTooMuch = maxBorrow + 1;
        vm.expectRevert();
        vm.prank(user);
        morpho.borrow(params, borrowTooMuch, 0, user, user);
    }
}

