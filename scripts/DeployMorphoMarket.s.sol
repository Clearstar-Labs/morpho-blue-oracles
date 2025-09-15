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

    function createMarket(MarketParams memory marketParams) external;
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
}

contract DeployMorphoMarket is Script {
    // Function to calculate market ID from parameters
    function getMarketId(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(marketParams));
    }
    
    function run() external {
        // Get all required addresses from environment variables
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");
        address loanToken = vm.envAddress("LOAN_TOKEN");
        address collateralToken = vm.envAddress("COLLATERAL_TOKEN");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address irm = vm.envAddress("IRM_ADDRESS");
        uint256 lltv = vm.envUint("LLTV");
        
        console2.log("=== Deploying Morpho Market ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Morpho contract:", morphoContract);
        console2.log("Loan token:", loanToken);
        console2.log("Collateral token:", collateralToken);
        console2.log("Oracle:", oracle);
        console2.log("IRM:", irm);
        console2.log("LLTV:");
        console2.log("LLTV value:", lltv);
        
        // Calculate market ID before creation
        IMorpho.MarketParams memory marketParams = IMorpho.MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        
        bytes32 marketId = getMarketId(marketParams);
        console2.log("Calculated Market ID:", vm.toString(marketId));
        
        // Deploy the market
        IMorpho morpho = IMorpho(morphoContract);
        
        console2.log("\n=== Creating Market ===");
        
        bool doBroadcast;
        try vm.envBool("SCRIPT_BROADCAST") returns (bool b) {
            doBroadcast = b;
        } catch {
            doBroadcast = true;
        }

        if (doBroadcast) {
            // Prefer explicit private key if provided
            try vm.envUint("PRIVATE_KEY") returns (uint256 pk) {
                vm.startBroadcast(pk);
            } catch {
                vm.startBroadcast();
            }
        }
        
        try morpho.createMarket(marketParams) {
            console2.log("Market created successfully!");
        } catch Error(string memory reason) {
            console2.log("Market creation failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Market creation failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Market creation failed");
        }
        
        // Verify market was created correctly
        console2.log("\n=== Verifying Market Parameters ===");
        IMorpho.MarketParams memory createdMarket;
        try morpho.idToMarketParams(marketId) returns (IMorpho.MarketParams memory params) {
            createdMarket = params;
            console2.log("Market parameters retrieved successfully");
        } catch Error(string memory reason) {
            console2.log("Failed to retrieve market parameters:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Failed to retrieve market parameters with low-level error");
            console2.logBytes(lowLevelData);
            revert("Failed to retrieve market parameters");
        }
        
        // Verify all parameters match
        require(createdMarket.loanToken == loanToken, "Loan token mismatch");
        require(createdMarket.collateralToken == collateralToken, "Collateral token mismatch");
        require(createdMarket.oracle == oracle, "Oracle mismatch");
        require(createdMarket.irm == irm, "IRM mismatch");
        require(createdMarket.lltv == lltv, "LLTV mismatch");
        
        console2.log("\n[SUCCESS] All parameters verified successfully!");
        
        if (doBroadcast) vm.stopBroadcast();
        
        // Market information
        console2.log("\n=== Market Summary ===");
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("Loan-to-Value Ratio:", (lltv * 100) / 1e18, "%");
        console2.log("Users can now:");
        console2.log("1. Supply collateral token as collateral");
        console2.log("2. Borrow loan token against collateral");
        console2.log("3. Loan token suppliers can lend to earn interest");
        console2.log("4. Borrowers pay interest on borrowed tokens");
        
        console2.log("\n=== Integration Details ===");
        console2.log("Use this Market ID in your frontend/integration:");
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("Morpho Contract:", morphoContract);
        console2.log("Loan Token:", loanToken);
        console2.log("Collateral Token:", collateralToken);
        console2.log("Oracle:", oracle);
        console2.log("IRM:", irm);
        
        console2.log("\n=== Next Steps ===");
        console2.log("1. Verify the oracle is working correctly");
        console2.log("2. Test market operations with small amounts");
        console2.log("3. Monitor market utilization and interest rates");
        console2.log("4. Set up liquidation monitoring if needed");
    }
}
