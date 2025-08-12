// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console2.sol";

// IERC20 interface for token operations
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Morpho Blue interface
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(
        MarketParams memory marketParams,
        uint256 assets,
        address onBehalf,
        bytes memory data
    ) external;

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

contract SupplyCollateral is Script {
    
    function getSupplyAmount(address user, address collateralToken) internal view returns (uint256) {
        // try vm.envUint("SUPPLY_AMOUNT") returns (uint256 amount) {
        //     return amount;
        // } catch {
        //     // Use full balance if no amount specified
        //     IERC20 token = IERC20(collateralToken);
        //     return token.balanceOf(user);
        // }
        IERC20 token = IERC20(collateralToken);
        return token.balanceOf(user);
    }

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
    
    function run() external {
        // Get all required addresses from environment variables
        address morphoContract = vm.envAddress("MORPHO_CONTRACT");

        // Get user address
        address user = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Get market parameters
        IMorpho.MarketParams memory marketParams = getMarketParams();
        bytes32 marketId = getMarketId(marketParams);

        // Get supply amount (may depend on user's balance)
        uint256 supplyAmount = getSupplyAmount(user, marketParams.collateralToken);

        // Get token info for display
        IERC20 collateralToken = IERC20(marketParams.collateralToken);
        string memory tokenSymbol;
        try collateralToken.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "TOKEN";
        }

        console2.log("=== Supplying Collateral to Morpho ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Morpho contract:", morphoContract);
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("Collateral token:", marketParams.collateralToken);
        console2.log("Token symbol:", tokenSymbol);
        console2.log("User address:", user);
        console2.log("Supply amount:", supplyAmount);

        // Check collateral balance for the intended user and current msg.sender
        uint256 userBalance = collateralToken.balanceOf(user);
        uint256 senderBalance = collateralToken.balanceOf(address(this));
        console2.log("User token balance:", userBalance);
        console2.log("Script contract token balance (should be 0):", senderBalance);

        require(userBalance >= supplyAmount, "Insufficient token balance");

        // Check current allowance
        uint256 currentAllowance = collateralToken.allowance(user, morphoContract);
        console2.log("Current allowance (user -> Morpho):", currentAllowance);

        // Broadcast from the intended user key so msg.sender == user
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Approve if needed (from user)
        if (currentAllowance < supplyAmount) {
            console2.log("Approving token spend from user:", user);
            console2.log("Approve amount:", supplyAmount);
            bool success = collateralToken.approve(morphoContract, supplyAmount);
            require(success, "Approval failed");
            console2.log("Approval successful");
        } else {
            console2.log("Sufficient allowance already exists");
        }
        // Re-check allowance after potential approve
        uint256 allowanceAfter = collateralToken.allowance(user, morphoContract);
        console2.log("Allowance after approve (user -> Morpho):", allowanceAfter);

        // Check position before supply
        IMorpho morpho = IMorpho(morphoContract);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);

        console2.log("\n=== Position Before Supply ===");
        console2.log("Supply shares:", supplySharesBefore);
        console2.log("Borrow shares:", borrowSharesBefore);
        console2.log("Collateral:", collateralBefore);

        // Supply collateral
        console2.log("\n=== Supplying Collateral ===");
        try morpho.supplyCollateral(marketParams, supplyAmount, user, "") {
            console2.log("Collateral supplied successfully!");
        } catch Error(string memory reason) {
            console2.log("Supply failed:", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Supply failed with low-level error");
            console2.logBytes(lowLevelData);
            revert("Supply failed");
        }

        // Check position after supply
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) = morpho.position(marketId, user);

        console2.log("\n=== Position After Supply ===");
        console2.log("Supply shares:", supplySharesAfter);
        console2.log("Borrow shares:", borrowSharesAfter);
        console2.log("Collateral:", collateralAfter);

        console2.log("\n=== Supply Summary ===");
        console2.log("Collateral added:", collateralAfter - collateralBefore);
        console2.log("Total collateral:", collateralAfter);

        vm.stopBroadcast();

        // Get loan token info for display
        IERC20 loanToken = IERC20(marketParams.loanToken);
        string memory loanTokenSymbol;
        try loanToken.symbol() returns (string memory symbol) {
            loanTokenSymbol = symbol;
        } catch {
            loanTokenSymbol = "LOAN_TOKEN";
        }

        console2.log("\n=== Next Steps ===");
        console2.log("1. You can now borrow", loanTokenSymbol, "against this collateral");
        console2.log("2. Maximum borrowable: Calculate based on oracle price and LLTV");
        console2.log("3. Monitor your position health");
        console2.log("4. Use borrow scripts to borrow against your collateral");
        console2.log("5. Market ID for reference:", vm.toString(marketId));
    }
}
