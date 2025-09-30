// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";

import {MarketParams, IMorpho, Id} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

interface IERC20Minimal {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IOracleMinimal {
    function price() external view returns (uint256);
}

interface ISuperOracle is IOracleMinimal {
    function updatePrice() external;
    function updateExecutor(address executor, bool allowed) external;
    function executors(address executor) external view returns (bool);
    function owner() external view returns (address);
    function latestAnswer() external view returns (int256);
    function latestAnswerTimestamp() external view returns (uint256);
    function answerDecimals() external view returns (uint8);
}

interface IAggregatorLike {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

bytes4 constant SELECTOR_LATEST_ANSWER = 0x50d25bcd;
bytes4 constant SELECTOR_LATEST_PRIMARY_TIME = 0xd4bda989;
bytes4 constant SELECTOR_LATEST_FALLBACK_TIME = 0x04e23dd4;
bytes4 constant SELECTOR_PRIMARY_ORACLE_ADDR = 0x7239e719;
bytes4 constant SELECTOR_FALLBACK_ORACLE_ADDR = 0x51ad0b73;
bytes4 constant SELECTOR_ANSWER_DECIMALS = 0xf4bb86e2;
bytes4 constant SELECTOR_LATEST_ROUND_DATA = 0xfeaf968c;
bytes4 constant SELECTOR_MAX_PRICE_AGE = 0x1584410a;

contract SuperUSDMorphoMarketForkTest is Test {
    IMorpho constant MORPHO = IMorpho(0x6c247b1F6182318877311737BaC0844bAa518F5e);
    address constant LOAN_TOKEN = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC.e
    address constant COLLATERAL_TOKEN = 0x139450C2dCeF827C9A2a0Bb1CB5506260940c9fd; // sSuperUSD
    address constant ORACLE_ADDRESS = 0x53A12A13F057a4B29190BC0721049c518d76F473;
    address constant IRM = 0x66F30587FB8D4206918deb78ecA7d5eBbafD06DA;
    uint256 constant LLTV = 915_000_000_000_000_000; // 91.5%
    uint8 constant EXPECTED_ANSWER_DECIMALS = 6; // observed onchain
    uint256 constant FEED_SCALE = 1e28; // matches onchain scaling

    function setUp() public {
        string memory rpc = vm.envString("ARB_RPC_URL");
        uint256 blockNumber = _tryEnvUint("ARB_FORK_BLOCK");
        if (blockNumber != 0) vm.createSelectFork(rpc, blockNumber);
        else vm.createSelectFork(rpc);
        assertEq(block.chainid, 42161, "not on Arbitrum fork");
    }

    function testOracleMetadata() public {
        address aggregator = _primaryOracleAddress();
        assertTrue(aggregator != address(0), "aggregator not set");

        assertEq(IERC20Metadata(LOAN_TOKEN).decimals(), 6, "loan token decimals");
        assertEq(IERC20Metadata(COLLATERAL_TOKEN).decimals(), 6, "collateral token decimals");

        uint8 answerDecimals = uint8(_callUintSelector(SELECTOR_ANSWER_DECIMALS, ORACLE_ADDRESS));
        assertEq(answerDecimals, EXPECTED_ANSWER_DECIMALS, "oracle feed decimals");

        string memory loanSymbol = IERC20Metadata(LOAN_TOKEN).symbol();
        string memory collSymbol = IERC20Metadata(COLLATERAL_TOKEN).symbol();
        emit log_string(string.concat("loan token:", loanSymbol));
        emit log_string(string.concat("collateral token:", collSymbol));
    }

    function testOracleMatchesLatestAnswer() public {
        IOracleMinimal oracle = IOracleMinimal(ORACLE_ADDRESS);
        uint256 oraclePrice = oracle.price();
        int256 latestAnswer = _callIntSelector(SELECTOR_LATEST_ANSWER, ORACLE_ADDRESS);
        uint256 updatedAt = _callUintSelector(SELECTOR_LATEST_PRIMARY_TIME, ORACLE_ADDRESS);

        assertTrue(latestAnswer > 0, "oracle latest answer not positive");
        assertGt(updatedAt, block.timestamp - 2 days, "oracle answer is stale");

        uint256 expected = uint256(latestAnswer) * FEED_SCALE;
        assertApproxEqRel(oraclePrice, expected, 1e8, "oracle price mismatch");
        assertGt(oraclePrice, 9e35, "oracle price too low");
        assertLt(oraclePrice, 12e35, "oracle price too high");
    }

    function testFallbackTimestampTracksBlockTime() public {
        IAggregatorLike fallbackOracle = IAggregatorLike(_fallbackOracleAddress());

        (, int256 answer1,, uint256 updatedAt1,) = fallbackOracle.latestRoundData();
        assertEq(updatedAt1, block.timestamp, "fallback pins timestamp to current block");

        vm.warp(block.timestamp + 3 days);

        (, int256 answer2,, uint256 updatedAt2,) = fallbackOracle.latestRoundData();
        assertEq(updatedAt2, block.timestamp, "fallback refreshes timestamp merely by reading");
        assertEq(answer2, answer1, "price changed without new observation");
    }

    function testFallbackRoundIdConstant() public {
        IAggregatorLike fallbackOracle = IAggregatorLike(_fallbackOracleAddress());

        (uint80 roundId1,, ,,) = fallbackOracle.latestRoundData();
        vm.warp(block.timestamp + 1 hours);
        (uint80 roundId2,, ,,) = fallbackOracle.latestRoundData();

        assertEq(roundId1, roundId2, "roundId should remain constant");
    }

    function testMorphoAcceptsFallbackAfterDormantPeriod() public {
        address primary = _primaryOracleAddress();
        address fallbackOracle = _fallbackOracleAddress();

        // Ensure this contract is executor
        _ensureExecutor(address(this));

        // Initial update with results in range
        int256 baseline = _callIntSelector(SELECTOR_LATEST_ANSWER, ORACLE_ADDRESS);
        vm.mockCall(primary, abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA), abi.encode(uint80(1), baseline, block.timestamp, block.timestamp, uint80(1)));
        vm.mockCall(fallbackOracle, abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA), abi.encode(uint80(1), baseline, block.timestamp, block.timestamp, uint80(1)));
        ISuperOracle(ORACLE_ADDRESS).updatePrice();
        uint256 baselinePrice = IOracleMinimal(ORACLE_ADDRESS).price();
        vm.clearMockedCalls();

        uint256 maxAge = _callUintSelector(SELECTOR_MAX_PRICE_AGE, ORACLE_ADDRESS);
        require(maxAge > 0, "oracle price should be >0");

        // Warp beyond maxAge
        vm.warp(block.timestamp + maxAge + 1);

        // Make primary out of range so fallback path is chosen
        int256 primaryOutOfRange = baseline * 2;
        vm.mockCall(primary, abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA), abi.encode(uint80(2), primaryOutOfRange, block.timestamp, block.timestamp, uint80(2)));

        // Fallback returns old price but timestamp is refreshed to block.timestamp
        vm.mockCall(
            fallbackOracle,
            abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA),
            abi.encode(uint80(2), baseline, block.timestamp, block.timestamp, uint80(2))
        );

        // Because fallback oracle sets timestamps to now internally, we expect Morpho oracle to accept it
        vm.expectCall(fallbackOracle, abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA));
        ISuperOracle(ORACLE_ADDRESS).updatePrice();

        uint256 fallbackTime = _callUintSelector(SELECTOR_LATEST_FALLBACK_TIME, ORACLE_ADDRESS);
        uint256 currentPrice = IOracleMinimal(ORACLE_ADDRESS).price();
        assertEq(block.timestamp - fallbackTime, 0, "fallback timestamp should appear fresh");
        assertEq(currentPrice, baselinePrice, "fallback price reused despite dormancy");

        vm.clearMockedCalls();
    }

    function testOracleRevertsIfNegativeAnswer() public {
        address aggregator = _fallbackOracleAddress();
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA),
            abi.encode(uint80(1), int256(-1), uint256(block.timestamp - 1), uint256(block.timestamp - 1), uint80(1))
        );
        vm.expectCall(aggregator, abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA));
        _ensureExecutor(address(this));
        bool succeeded;
        vm.startPrank(address(this));
        try ISuperOracle(ORACLE_ADDRESS).updatePrice() {
            succeeded = true;
        } catch {
            succeeded = false;
        }
        vm.stopPrank();
        if (succeeded) {
            int256 stored = _callIntSelector(SELECTOR_LATEST_ANSWER, ORACLE_ADDRESS);
            emit log_named_int("stored answer after negative update", stored);
        }
        assertFalse(succeeded, "oracle accepted negative answer");
        vm.clearMockedCalls();
    }

    function testOracleRevertsIfZeroAnswer() public {
        address aggregator = _fallbackOracleAddress();
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA),
            abi.encode(uint80(1), int256(0), uint256(block.timestamp - 1), uint256(block.timestamp - 1), uint80(1))
        );
        _ensureExecutor(address(this));
        bool succeeded;
        vm.startPrank(address(this));
        try ISuperOracle(ORACLE_ADDRESS).updatePrice() {
            succeeded = true;
        } catch {
            succeeded = false;
        }
        vm.stopPrank();
        if (succeeded) {
            int256 stored = _callIntSelector(SELECTOR_LATEST_ANSWER, ORACLE_ADDRESS);
            emit log_named_int("stored answer after zero update", stored);
        }
        assertFalse(succeeded, "oracle accepted zero answer");
        vm.clearMockedCalls();
    }

    function testOracleRevertsIfStale() public {
        address aggregator = _fallbackOracleAddress();
        uint256 staleTimestamp = block.timestamp - 4 days;
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA),
            abi.encode(uint80(1), int256(1_000_000000), uint256(staleTimestamp), uint256(staleTimestamp), uint80(1))
        );
        _ensureExecutor(address(this));
        bool succeeded;
        vm.startPrank(address(this));
        try ISuperOracle(ORACLE_ADDRESS).updatePrice() {
            succeeded = true;
        } catch {
            succeeded = false;
        }
        vm.stopPrank();
        if (succeeded) {
            uint256 storedTimestamp = _callUintSelector(SELECTOR_LATEST_FALLBACK_TIME, ORACLE_ADDRESS);
            emit log_named_uint("stored timestamp after stale update", storedTimestamp);
        }
        assertFalse(succeeded, "oracle accepted stale data");
        vm.clearMockedCalls();
    }

    function testOracleRevertsIfAnswerTooLarge() public {
        address aggregator = _fallbackOracleAddress();
        int256 unsafeAnswer = int256(uint256(type(uint224).max));
        vm.mockCall(
            aggregator,
            abi.encodeWithSelector(SELECTOR_LATEST_ROUND_DATA),
            abi.encode(uint80(1), unsafeAnswer, uint256(block.timestamp - 1), uint256(block.timestamp - 1), uint80(1))
        );
        _ensureExecutor(address(this));
        bool succeeded;
        vm.startPrank(address(this));
        try ISuperOracle(ORACLE_ADDRESS).updatePrice() {
            succeeded = true;
        } catch {
            succeeded = false;
        }
        vm.stopPrank();
        if (succeeded) {
            int256 stored = _callIntSelector(SELECTOR_LATEST_ANSWER, ORACLE_ADDRESS);
            emit log_named_int("stored answer after oversized update", stored);
        }
        assertFalse(succeeded, "oracle accepted oversized answer");
        vm.clearMockedCalls();
    }

    function testMarketDeploymentAndBorrowBounds() public {
        MarketParams memory params = MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE_ADDRESS,
            irm: IRM,
            lltv: LLTV
        });

        Id marketId = _marketId(params);
        MarketParams memory existing = MORPHO.idToMarketParams(marketId);
        assertEq(existing.loanToken, address(0), "market already exists on fork");

        MORPHO.createMarket(params);
        MarketParams memory created = MORPHO.idToMarketParams(marketId);
        assertEq(created.loanToken, params.loanToken, "loan token mismatch");
        assertEq(created.collateralToken, params.collateralToken, "collateral token mismatch");
        assertEq(created.oracle, params.oracle, "oracle mismatch");
        assertEq(created.irm, params.irm, "irm mismatch");
        assertEq(created.lltv, params.lltv, "lltv mismatch");

        address supplier = address(0xA11CE);
        address borrower = address(0xB0B0B0);
        vm.label(supplier, "supplier");
        vm.label(borrower, "borrower");

        uint256 liquidity = 20_000 * 1e6; // 20k USDC liquidity
        deal(LOAN_TOKEN, supplier, liquidity);

        vm.startPrank(supplier);
        IERC20Minimal(LOAN_TOKEN).approve(address(MORPHO), liquidity);
        MORPHO.supply(params, liquidity, 0, supplier, "");
        vm.stopPrank();

        uint256 collateralAmount = 10_000 * 1e6; // 10k sSuperUSD
        deal(COLLATERAL_TOKEN, borrower, collateralAmount);

        vm.startPrank(borrower);
        IERC20Minimal(COLLATERAL_TOKEN).approve(address(MORPHO), collateralAmount);
        MORPHO.supplyCollateral(params, collateralAmount, borrower, "");
        vm.stopPrank();

        uint256 oraclePrice = IOracleMinimal(ORACLE_ADDRESS).price();
        uint256 maxBorrowValue = collateralAmount * oraclePrice / 1e36;
        uint256 borrowCap = maxBorrowValue * LLTV / 1e18;
        assertGt(borrowCap, 0, "borrow cap should be positive");

        uint256 borrowOk = borrowCap - 1e6; // leave 1 USDC buffer to avoid rounding issues
        vm.prank(borrower);
        MORPHO.borrow(params, borrowOk, 0, borrower, borrower);

        uint256 borrowTooMuch = borrowCap + 1e6;
        vm.expectRevert();
        vm.prank(borrower);
        MORPHO.borrow(params, borrowTooMuch, 0, borrower, borrower);
    }

    function _marketId(MarketParams memory params) internal pure returns (Id) {
        bytes32 rawId = keccak256(abi.encode(params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv));
        return Id.wrap(rawId);
    }

    function _ensureExecutor(address executor) internal {
        ISuperOracle oracle = ISuperOracle(ORACLE_ADDRESS);
        if (!oracle.executors(executor)) {
            address owner = oracle.owner();
            vm.startPrank(owner);
            oracle.updateExecutor(executor, true);
            vm.stopPrank();
            assertTrue(oracle.executors(executor), "executor grant failed");
        }
    }

    function _primaryOracleAddress() internal view returns (address) {
        uint256 raw = _callUintSelector(SELECTOR_PRIMARY_ORACLE_ADDR, ORACLE_ADDRESS);
        return address(uint160(raw));
    }

    function _fallbackOracleAddress() internal view returns (address) {
        uint256 raw = _callUintSelector(SELECTOR_FALLBACK_ORACLE_ADDR, ORACLE_ADDRESS);
        return address(uint160(raw));
    }

    function _callUintSelector(bytes4 selector, address target) internal view returns (uint256) {
        (bool success, bytes memory data) = target.staticcall(abi.encodeWithSelector(selector));
        require(success && data.length >= 32, "oracle call failed");
        return abi.decode(data, (uint256));
    }

    function _callIntSelector(bytes4 selector, address target) internal view returns (int256) {
        (bool success, bytes memory data) = target.staticcall(abi.encodeWithSelector(selector));
        require(success && data.length >= 32, "oracle call failed");
        return abi.decode(data, (int256));
    }

    function _tryEnvUint(string memory key) internal view returns (uint256 value) {
        try vm.envUint(key) returns (uint256 v) {
            return v;
        } catch {
            return 0;
        }
    }
}
