// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

// Morpho Blue interface
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Market {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }

    function market(bytes32 id) external view returns (Market memory);
    function borrowRate(MarketParams memory marketParams, Market memory market) external view returns (uint256);
    function supplyRate(MarketParams memory marketParams, Market memory market) external view returns (uint256);
}

// Oracle interface
interface IOracle {
    function price() external view returns (uint256);
}

// IERC20 interface for token info
interface IERC20 {
    function symbol() external view returns (string memory);
}

// IRM interface
interface IIRM {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    struct Market {
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 totalBorrowAssets;
        uint128 totalBorrowShares;
        uint128 lastUpdate;
        uint128 fee;
    }

    function borrowRate(MarketParams memory marketParams, Market memory market) external view returns (uint256);
}

contract ReadMarketUtilization is Script {
    
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

    function getTokenSymbol(address token) internal view returns (string memory) {
        try IERC20(token).symbol() returns (string memory symbol) {
            return symbol;
        } catch {
            return "TOKEN";
        }
    }
    
    function formatRate(uint256 rate) internal pure returns (string memory) {
        // Convert from per-second rate to APY percentage
        // rate is in 1e18 scale, per second
        uint256 secondsPerYear = 365 * 24 * 60 * 60;
        uint256 apyBasisPoints = (rate * secondsPerYear * 10000) / 1e18;
        return string(abi.encodePacked(vm.toString(apyBasisPoints / 100), ".", vm.toString(apyBasisPoints % 100), "%"));
    }
    
    function run() external view {
        // Get all required addresses from environment variables
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");

        // Get market parameters and ID
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        // Get token symbols for display
        string memory loanTokenSymbol = getTokenSymbol(marketParams.loanToken);
        string memory collateralTokenSymbol = getTokenSymbol(marketParams.collateralToken);

        // Calculate LLTV percentage with decimal precision
        uint256 lltvPercent = (marketParams.lltv * 1000) / 1e18; // Get to 0.1% precision

        console.log("=== Morpho Market Utilization Report ===");
        console.log("Chain ID:", block.chainid);
        console.log("Market ID:", vm.toString(marketId));
        console.log("Loan Token:", marketParams.loanToken);
        console.log("Loan Token Symbol:", loanTokenSymbol);
        console.log("Collateral Token:", marketParams.collateralToken);
        console.log("Collateral Token Symbol:", collateralTokenSymbol);
        console.log("Oracle:", marketParams.oracle);
        console.log("IRM:", marketParams.irm);
        // Display LLTV with decimal precision (e.g., 91.5%)
        console.log("LLTV:", string(abi.encodePacked(vm.toString(lltvPercent / 10), ".", vm.toString(lltvPercent % 10), "%")));

        // Get market data
        IMorpho morpho = IMorpho(morphoContract);
        IMorpho.Market memory market;

        try morpho.market(marketId) returns (IMorpho.Market memory marketData) {
            market = marketData;
            console.log("\n=== Market State ===");
            console2.log("Total Supply Assets:", loanTokenSymbol, ":", uint256(market.totalSupplyAssets));
            console2.log("Total Supply Shares:", uint256(market.totalSupplyShares));
            console2.log("Total Borrow Assets:", loanTokenSymbol, ":", uint256(market.totalBorrowAssets));
            console2.log("Total Borrow Shares:", uint256(market.totalBorrowShares));
            console2.log("Last Update:", uint256(market.lastUpdate));
            console2.log("Fee:", uint256(market.fee));
        } catch {
            console.log("\n=== Market State ===");
            console.log("ERROR: Could not fetch market data - market may not exist");
            console.log("Please ensure the market has been deployed with the correct parameters");
            return;
        }
        
        // Calculate utilization
        uint256 utilization = 0;
        if (market.totalSupplyAssets > 0) {
            utilization = (uint256(market.totalBorrowAssets) * 1e18) / uint256(market.totalSupplyAssets);
        }
        
        console.log("\n=== Utilization Metrics ===");
        console2.log("Utilization (1e18 = 100%):", utilization);
        console2.log("Utilization Percentage:", (utilization * 100) / 1e18);

        // Calculate available liquidity
        uint256 availableLiquidity = uint256(market.totalSupplyAssets) - uint256(market.totalBorrowAssets);
        console2.log("Available Liquidity:", loanTokenSymbol, ":", availableLiquidity);
        
        // Get interest rates
        try morpho.borrowRate(marketParams, market) returns (uint256 borrowRatePerSecond) {
            console.log("\n=== Interest Rates ===");
            console2.log("Borrow Rate (per second, 1e18):", borrowRatePerSecond);
            console.log("Borrow Rate APY:", formatRate(borrowRatePerSecond));

            // Calculate supply rate (borrow rate * utilization * (1 - fee))
            uint256 supplyRatePerSecond = (borrowRatePerSecond * utilization * (1e18 - uint256(market.fee))) / (1e18 * 1e18);
            console2.log("Supply Rate (per second, 1e18):", supplyRatePerSecond);
            console.log("Supply Rate APY:", formatRate(supplyRatePerSecond));
        } catch {
            console.log("\n=== Interest Rates ===");
            console.log("Could not fetch interest rates");
        }
        
        // Get oracle price
        try IOracle(marketParams.oracle).price() returns (uint256 oraclePrice) {
            console.log("\n=== Oracle Price ===");
            console2.log("Oracle Price (scaled by 1e36):", oraclePrice);
            console.log("Price represents:", collateralTokenSymbol, "/", loanTokenSymbol);

            // Convert to human readable (scaled down from 1e36)
            uint256 humanPrice = oraclePrice / 1e30; // 1e36 - 6 = 1e30 (assuming 6 decimal loan token)
            console2.log("Human readable price:", humanPrice);
        } catch {
            console.log("\n=== Oracle Price ===");
            console.log("Could not fetch oracle price");
        }
        
        // Market health summary
        console.log("\n=== Market Summary ===");
        if (utilization == 0) {
            console.log("Status: No borrowing activity");
        } else if (utilization < 0.5e18) {
            console.log("Status: Low utilization - consider lower rates");
        } else if (utilization < 0.8e18) {
            console.log("Status: Moderate utilization - healthy market");
        } else if (utilization < 0.95e18) {
            console.log("Status: High utilization - good for lenders");
        } else {
            console.log("Status: Very high utilization - limited liquidity");
        }
        
        console2.log("Total Value Locked:", loanTokenSymbol, ":", uint256(market.totalSupplyAssets));
        console2.log("Total Borrowed:", loanTokenSymbol, ":", uint256(market.totalBorrowAssets));
        console2.log("Available for Withdrawal:", loanTokenSymbol, ":", availableLiquidity);
    }
}
