// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";

// Import the PendleChainlinkOracle from the Pendle repository
// Note: This would require adding the Pendle repository as a dependency in your project
// You can add it using: forge install pendle-finance/pendle-core-v2-public
import {PendleChainlinkOracle, PendleOracleType} from "pendle-core-v2-public/contracts/oracles/PtYtLpOracle/chainlink/PendleChainlinkOracle.sol";

/**
 * @title DeployPendleChainlinkOracle
 * @notice Script to deploy the PendleChainlinkOracle contract from the Pendle repository
 * @dev Run with:
        source .env

        forge script scripts/DeployPendleChainlinkOracle.s.sol:DeployPendleChainlinkOracle
            --rpc-url $ETH_RPC_URL   
            --private-key $PRIVATE_KEY   
            --broadcast   
            --verify   
            --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployPendleChainlinkOracle is Script {
    // Default values for other parameters - can be overridden via environment variables
    uint32 public constant DEFAULT_TWAP_DURATION = 1800; // 30 minutes in seconds
    PendleOracleType public constant DEFAULT_ORACLE_TYPE = PendleOracleType.PT_TO_ASSET; // PT to Asset price

    function run() public returns (PendleChainlinkOracle oracle) {
        // Get market address from environment - no default provided, will fail if not set
        address market = vm.envAddress("PENDLE_MARKET");
        
        // Get other deployment parameters from environment or use defaults
        uint32 twapDuration = uint32(vm.envOr("TWAP_DURATION", uint256(DEFAULT_TWAP_DURATION)));
        PendleOracleType oracleType = PendleOracleType(vm.envOr("ORACLE_TYPE", uint256(DEFAULT_ORACLE_TYPE)));
        
        // Set up fork if needed
        string memory rpcUrl = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        // Set gas price if provided
        uint256 gasPrice = vm.envOr("GAS_PRICE", uint256(0));
        if (gasPrice > 0) {
            console.log("Using custom gas price:");
            console.logUint(gasPrice);
            vm.txGasPrice(gasPrice);
        }
        
        console.log("Deploying PendleChainlinkOracle with parameters:");
        console.log("Market:", market);
        console2.log("TWAP Duration:", twapDuration);
        console2.log("Oracle Type:", uint256(oracleType));
        
        // Start the broadcast to record and send transactions
        // vm.startBroadcast();
        
        // // Deploy the oracle
        // oracle = new PendleChainlinkOracle(
        //     market,
        //     twapDuration,
        //     oracleType
        // );
        
        // console.log("PendleChainlinkOracle deployed at:", address(oracle));
        
        // vm.stopBroadcast();
        
        // // Verify the deployment
        // verifyDeployment(oracle, market, twapDuration, oracleType);
        
        // // Test the oracle
        // testOracle(oracle);
        
        // return oracle;
    }
    
    function verifyDeployment(
        PendleChainlinkOracle oracle,
        address expectedMarket,
        uint32 expectedTwapDuration,
        PendleOracleType expectedOracleType
    ) internal view {
        console.log("\nVerifying deployment...");
        
        address actualMarket = oracle.market();
        uint32 actualTwapDuration = oracle.twapDuration();
        PendleOracleType actualOracleType = oracle.baseOracleType();
        
        console.log("Market - Expected:", expectedMarket, "Actual:", actualMarket);
        console.log("TWAP Duration - Expected:", expectedTwapDuration, "Actual:", actualTwapDuration);
        console.log("Oracle Type - Expected:", uint256(expectedOracleType), "Actual:", uint256(actualOracleType));
        
        require(actualMarket == expectedMarket, "Market address mismatch");
        require(actualTwapDuration == expectedTwapDuration, "TWAP duration mismatch");
        require(actualOracleType == expectedOracleType, "Oracle type mismatch");
        
        console.log("Deployment verified successfully!");
    }
    
    function testOracle(PendleChainlinkOracle oracle) internal view {
        console.log("\nTesting oracle...");
        
        // Get the decimals and description
        uint8 oracleDecimals = oracle.decimals();
        string memory oracleDescription = oracle.description();
        
        console.log("Oracle decimals:", oracleDecimals);
        console.log("Oracle description:", oracleDescription);
        
        // Get the latest price data
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = 
            oracle.latestRoundData();
        
        console.log("Latest round data:");
        console.log("  roundId:", roundId);
        console.log("  answer:");
        console.logInt(answer);
        console.log("  startedAt:", startedAt);
        console.log("  updatedAt:", updatedAt);
        console.log("  answeredInRound:", answeredInRound);
        
        // Additional oracle-specific information
        uint256 fromTokenScale = oracle.fromTokenScale();
        uint256 toTokenScale = oracle.toTokenScale();
        
        console.log("From Token Scale:");
        console.logUint(fromTokenScale);
        console.log("To Token Scale:");
        console.logUint(toTokenScale);
        
        console.log("Oracle test completed!");
    }
}
