// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {PendleSparkLinearDiscountOracle} from "../src/pendle/PendleSparkLinearDiscountOracle.sol";

/**
 * @title DeployPendleSparkLinearDiscountOracle
 * @notice Script to deploy the PendleSparkLinearDiscountOracle contract
 * @dev Run with:
        source .env

        forge script scripts/DeployPendleSparkLinearDiscountOracle.s.sol:DeployPendleSparkLinearDiscountOracle
            --rpc-url $ETH_RPC_URL   
            --private-key $PRIVATE_KEY   
            --broadcast   
            --verify   
            --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployPendleSparkLinearDiscountOracle is Script {
    // Default values - can be overridden via environment variables
    address public constant DEFAULT_PT = 0x21aacE56a8F21210b7E76d8eF1a77253Db85BF0a; // PT fxSAVE
    uint256 public constant DEFAULT_BASE_DISCOUNT_PER_YEAR = 0.20e18; // 20% discount per year

    function run() public returns (PendleSparkLinearDiscountOracle oracle) {
        // Get deployment parameters from environment or use defaults
        address pt = vm.envOr("PT_ADDRESS", DEFAULT_PT);
        uint256 baseDiscountPerYear = vm.envOr("BASE_DISCOUNT_PER_YEAR", DEFAULT_BASE_DISCOUNT_PER_YEAR);
        
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
        
        console.log("Deploying PendleSparkLinearDiscountOracle with parameters:");
        console.log("PT Token:", pt);
        console.log("Base Discount Per Year:");
        console2.logUint(baseDiscountPerYear);
        
        // Start the broadcast to record and send transactions
        vm.startBroadcast();
        
        // Deploy the oracle directly
        oracle = new PendleSparkLinearDiscountOracle(
            pt,
            baseDiscountPerYear
        );
        
        console.log("PendleSparkLinearDiscountOracle deployed at:", address(oracle));
        
        vm.stopBroadcast();
        
        // Verify the deployment
        verifyDeployment(oracle, pt, baseDiscountPerYear);
        
        return oracle;
    }
    
    function verifyDeployment(
        PendleSparkLinearDiscountOracle oracle,
        address expectedPT,
        uint256 expectedBaseDiscountPerYear
    ) internal view {
        console.log("\nVerifying deployment...");
        
        address actualPT = oracle.PT();
        uint256 actualBaseDiscountPerYear = oracle.baseDiscountPerYear();
        uint256 actualMaturity = oracle.maturity();
        
        console.log("PT Token - Expected:", expectedPT, "Actual:", actualPT);
        console.log("Base Discount Per Year - Expected:");
        console.logUint(expectedBaseDiscountPerYear);
        console.log("Actual:");
        console.logUint(actualBaseDiscountPerYear);
        console.log("Maturity:");
        console.logUint(actualMaturity);
        
        require(actualPT == expectedPT, "PT token address mismatch");
        require(actualBaseDiscountPerYear == expectedBaseDiscountPerYear, "Base discount per year mismatch");
        
        console.log("Deployment verified successfully!");
    }
}