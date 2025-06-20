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
    // Base network chain ID
    uint256 constant BASE_CHAIN_ID = 8453;
    
    // Contract addresses on Base
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ADAPTIVE_CURVE_IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    
    // Token addresses on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WSTUSR = 0xB67675158B412D53fe6B68946483ba920b135bA1;
    
    // Oracle address
    address constant ORACLE = 0x31fB76310E7AA59f4994af8cb6a420c39669604A;
    
    // LLTV: 91.5%
    uint256 constant LLTV = 915000000000000000;
    
    function getMarketParams() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: USDC,
            collateralToken: WSTUSR,
            oracle: ORACLE,
            irm: ADAPTIVE_CURVE_IRM,
            lltv: LLTV
        });
    }
    
    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
    
    function formatRate(uint256 rate) internal pure returns (string memory) {
        // Convert from per-second rate to APY percentage
        // rate is in 1e18 scale, per second
        uint256 secondsPerYear = 365 * 24 * 60 * 60;
        uint256 apyBasisPoints = (rate * secondsPerYear * 10000) / 1e18;
        return string(abi.encodePacked(vm.toString(apyBasisPoints / 100), ".", vm.toString(apyBasisPoints % 100), "%"));
    }
    
    function run() external view {
        // Ensure we're on Base network
        require(block.chainid == BASE_CHAIN_ID, "Must be on Base network");
        
        // Get market parameters and ID
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);
        
        console.log("=== Morpho Market Utilization Report ===");
        console.log("Market ID:", vm.toString(marketId));
        console.log("Loan Token (USDC):", USDC);
        console.log("Collateral Token (wstUSR):", WSTUSR);
        console.log("Oracle:", ORACLE);
        console.log("IRM:", ADAPTIVE_CURVE_IRM);
        console.log("LLTV: 91.5%");
        
        // Get market data
        IMorpho morpho = IMorpho(MORPHO);
        IMorpho.Market memory market;

        try morpho.market(marketId) returns (IMorpho.Market memory marketData) {
            market = marketData;
            console.log("\n=== Market State ===");
            console2.log("Total Supply Assets (USDC):", uint256(market.totalSupplyAssets));
            console2.log("Total Supply Shares:", uint256(market.totalSupplyShares));
            console2.log("Total Borrow Assets (USDC):", uint256(market.totalBorrowAssets));
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
        console2.log("Available Liquidity (USDC):", availableLiquidity);
        
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
        try IOracle(ORACLE).price() returns (uint256 oraclePrice) {
            console.log("\n=== Oracle Price ===");
            console2.log("wstUSR/USDC Price (scaled by 1e36):", oraclePrice);

            // Convert to human readable (assuming 18 decimals for wstUSR, 6 for USDC)
            uint256 humanPrice = oraclePrice / 1e30; // 1e36 - 6 = 1e30
            console2.log("wstUSR/USDC Price (human readable):", humanPrice);
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
        
        console2.log("Total Value Locked (USDC):", uint256(market.totalSupplyAssets));
        console2.log("Total Borrowed (USDC):", uint256(market.totalBorrowAssets));
        console2.log("Available for Withdrawal (USDC):", availableLiquidity);
    }
}
