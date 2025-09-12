// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";

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
        
        console.log("=== Deploying Morpho Market ===");
        console.log("Chain ID:", block.chainid);
        console.log("Morpho contract:", morphoContract);
        console.log("Loan token:", loanToken);
        console.log("Collateral token:", collateralToken);
        console.log("Oracle:", oracle);
        console.log("IRM:", irm);
        console.log("LLTV:");
        console.log("LLTV value:", lltv);
        
        // Calculate market ID before creation
        IMorpho.MarketParams memory marketParams = IMorpho.MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
        
        bytes32 marketId = getMarketId(marketParams);
        console.log("Calculated Market ID:", vm.toString(marketId));
        
        // Deploy the market
        IMorpho morpho = IMorpho(morphoContract);
        
        console.log("\n=== Creating Market ===");
        
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
            console.log("Market created successfully!");
        } catch Error(string memory reason) {
            console.log("Market creation failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Market creation failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Market creation failed");
        }
        
        // Verify market was created correctly
        console.log("\n=== Verifying Market Parameters ===");
        IMorpho.MarketParams memory createdMarket;
        try morpho.idToMarketParams(marketId) returns (IMorpho.MarketParams memory params) {
            createdMarket = params;
            console.log("Market parameters retrieved successfully");
        } catch Error(string memory reason) {
            console.log("Failed to retrieve market parameters:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Failed to retrieve market parameters with low-level error");
            console.logBytes(lowLevelData);
            revert("Failed to retrieve market parameters");
        }
        
        // Verify all parameters match
        require(createdMarket.loanToken == loanToken, "Loan token mismatch");
        require(createdMarket.collateralToken == collateralToken, "Collateral token mismatch");
        require(createdMarket.oracle == oracle, "Oracle mismatch");
        require(createdMarket.irm == irm, "IRM mismatch");
        require(createdMarket.lltv == lltv, "LLTV mismatch");
        
        console.log("\n[SUCCESS] All parameters verified successfully!");
        
        if (doBroadcast) vm.stopBroadcast();
        
        // Market information
        console.log("\n=== Market Summary ===");
        console.log("Market ID:", vm.toString(marketId));
        console.log("Loan-to-Value Ratio:", (lltv * 100) / 1e18, "%");
        console.log("Users can now:");
        console.log("1. Supply collateral token as collateral");
        console.log("2. Borrow loan token against collateral");
        console.log("3. Loan token suppliers can lend to earn interest");
        console.log("4. Borrowers pay interest on borrowed tokens");
        
        console.log("\n=== Integration Details ===");
        console.log("Use this Market ID in your frontend/integration:");
        console.log("Market ID:", vm.toString(marketId));
        console.log("Morpho Contract:", morphoContract);
        console.log("Loan Token:", loanToken);
        console.log("Collateral Token:", collateralToken);
        console.log("Oracle:", oracle);
        console.log("IRM:", irm);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify the oracle is working correctly");
        console.log("2. Test market operations with small amounts");
        console.log("3. Monitor market utilization and interest rates");
        console.log("4. Set up liquidation monitoring if needed");
    }
}
