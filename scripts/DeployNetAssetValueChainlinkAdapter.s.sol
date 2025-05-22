// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {NetAssetValueChainlinkAdapter, INetAssetValue} from "../src/fxusd-nav-adapter/NetAssetValueChainlinkAdapter.sol";

/**
 * @title DeployNetAssetValueChainlinkAdapter
 * @notice Script to deploy the NetAssetValueChainlinkAdapter contract
 * @dev Run with:
        source .env

        forge script scripts/DeployNetAssetValueChainlinkAdapter.s.sol:DeployNetAssetValueChainlinkAdapter --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
 */
contract DeployNetAssetValueChainlinkAdapter is Script {
    // Default values - can be overridden via environment variables
    address public constant FX_SAVE = 0x7743e50F534a7f9F1791DdE7dCD89F7783Eefc39; // fxToken address
    address public constant ADMIN = 0x72882eb5D27C7088DFA6DDE941DD42e5d184F0ef; // Default admin address

    function run() public returns (NetAssetValueChainlinkAdapter adapter) {
        // Connect to the token to get current NAV
        INetAssetValue navToken = INetAssetValue(FX_SAVE);
        uint256 currentNav;
        
        // Try to get the current NAV
        try navToken.nav() returns (uint256 nav) {
            currentNav = nav;
            console.log("Current NAV:", currentNav);
        } catch {
            revert("Failed to get NAV from token");
        }
        
        // Calculate maxCap as 20% above current NAV (within the 5-50% range required by the contract)
        uint256 maxCap = (currentNav * 120) / 100; // 20% above current NAV
        
        console.log("Deploying NetAssetValueChainlinkAdapter with parameters:");
        console.log("Token:", FX_SAVE);
        console2.log("Max Cap:", maxCap);
        console.log("Admin:", ADMIN);
        
        // Start the broadcast to record and send transactions
        vm.startBroadcast();
        
        // Deploy the adapter
        adapter = new NetAssetValueChainlinkAdapter(
            INetAssetValue(FX_SAVE),
            maxCap,
            ADMIN
        );
        
        console.log("NetAssetValueChainlinkAdapter deployed at:", address(adapter));
        
        vm.stopBroadcast();
        
        // Verify the deployment
        verifyDeployment(adapter, FX_SAVE, maxCap, ADMIN);
        
        return adapter;
    }
    
    function verifyDeployment(
        NetAssetValueChainlinkAdapter adapter,
        address expectedToken,
        uint256 expectedMaxCap,
        address expectedAdmin
    ) internal view {
        console.log("\nVerifying deployment...");
        
        address actualToken = address(adapter.token());
        uint256 actualMaxCap = adapter.maxCap();
        address actualAdmin = adapter.admin();
        
        console.log("Token - Expected:", expectedToken, "Actual:", actualToken);
        console.log("Max Cap - Expected:", expectedMaxCap, "Actual:", actualMaxCap);
        console.log("Admin - Expected:", expectedAdmin, "Actual:", actualAdmin);
        
        require(actualToken == expectedToken, "Token address mismatch");
        require(actualMaxCap == expectedMaxCap, "Max cap mismatch");
        require(actualAdmin == expectedAdmin, "Admin address mismatch");
        
        console.log("Deployment verified successfully!");
    }
}
