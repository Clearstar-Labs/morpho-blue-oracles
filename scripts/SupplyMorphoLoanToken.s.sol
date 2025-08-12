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

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesReturned);

    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);
}

contract SupplyMorphoLoanToken is Script {
    
    function getSupplyAmount(address user, address loanToken) internal view returns (uint256) {
        try vm.envUint("SUPPLY_AMOUNT") returns (uint256 amount) {
            return amount;
        } catch {
            // Use full balance if no amount specified
            IERC20 token = IERC20(loanToken);
            return token.balanceOf(user);
        }
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
        uint256 supplyAmount = getSupplyAmount(user, marketParams.loanToken);

        // Get token info for display
        IERC20 loanToken = IERC20(marketParams.loanToken);
        string memory tokenSymbol;
        try loanToken.symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "TOKEN";
        }

        console2.log("=== Supplying Loan Token to Morpho Market ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Morpho contract:", morphoContract);
        console2.log("Market ID:", vm.toString(marketId));
        console2.log("Loan token:", marketParams.loanToken);
        console2.log("Token symbol:", tokenSymbol);
        console2.log("User address:", user);
        console2.log("Supply amount:", supplyAmount);

        // Check loan token balance (user and script)
        uint256 userBalance = loanToken.balanceOf(user);
        uint256 senderBalance = loanToken.balanceOf(address(this));
        console2.log("User token balance:", userBalance);
        console2.log("Script contract token balance (should be 0):", senderBalance);

        require(userBalance >= supplyAmount, "Insufficient token balance");

        // Check current allowance
        uint256 currentAllowance = loanToken.allowance(user, morphoContract);
        console2.log("Current allowance (user -> Morpho):", currentAllowance);

        // Broadcast from user key
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Approve if needed
        if (currentAllowance < supplyAmount) {
            console2.log("Approving token spend from user:", user);
            console2.log("Approve amount:", supplyAmount);
            bool success = loanToken.approve(morphoContract, supplyAmount);
            require(success, "Approval failed");
            console2.log("Approval successful");
        } else {
            console2.log("Sufficient allowance already exists");
        }
        // Re-check allowance
        uint256 allowanceAfter = loanToken.allowance(user, morphoContract);
        console2.log("Allowance after approve (user -> Morpho):", allowanceAfter);

        // Check position before supply
        IMorpho morpho = IMorpho(morphoContract);
        (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = morpho.position(marketId, user);

        console2.log("\n=== Position Before Supply ===");
        console2.log("Supply shares:", supplySharesBefore);
        console2.log("Borrow shares:", borrowSharesBefore);
        console2.log("Collateral:", collateralBefore);

        // Supply loan token (using 0 for shares means we want to supply exact assets)
        console2.log("\n=== Supplying Loan Token ===");
        try morpho.supply(marketParams, supplyAmount, 0, user, "") returns (uint256 assetsSupplied, uint256 sharesReturned) {
            console2.log("Loan token supplied successfully!");
            console2.log("Assets supplied:", assetsSupplied);
            console2.log("Shares returned:", sharesReturned);
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
        console2.log("Supply shares added:", supplySharesAfter - supplySharesBefore);
        console2.log("Total supply shares:", supplySharesAfter);
        console2.log(tokenSymbol, "supplied to market for borrowers");

        vm.stopBroadcast();

        // Get collateral token info for display
        IERC20 collateralToken = IERC20(marketParams.collateralToken);
        string memory collateralSymbol;
        try collateralToken.symbol() returns (string memory symbol) {
            collateralSymbol = symbol;
        } catch {
            collateralSymbol = "COLLATERAL_TOKEN";
        }

        console2.log("\n=== Next Steps ===");
        console2.log("1. Your", tokenSymbol, "is now available for borrowers to borrow");
        console2.log("2. You will earn interest as borrowers pay interest");
        console2.log("3. You can withdraw your", tokenSymbol, "(subject to utilization)");
        console2.log("4. Monitor market utilization and interest rates");
        console2.log("5. Borrowers will use", collateralSymbol, "as collateral");
        console2.log("6. Market ID for reference:", vm.toString(marketId));
    }
}
