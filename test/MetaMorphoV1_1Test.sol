// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Define minimal interfaces for MetaMorpho
interface IMetaMorphoV1_1 {
    // Define MarketParams struct within the interface
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    
    // Market allocation struct
    struct MarketAllocation {
        MarketParams marketParams;
        uint256 assets;
    }
    
    // Market config struct
    struct MarketConfig {
        uint184 cap;
        bool enabled;
        uint64 removableAt;
    }
    
    // Basic ERC20 functions
    function balanceOf(address account) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    
    // Admin functions
    function setCurator(address newCurator) external;
    function setIsAllocator(address allocator, bool isAllocator) external;
    
    // Market management
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;
    function config(bytes32 id) external view returns (MarketConfig memory);
    function setSupplyQueue(bytes32[] memory newSupplyQueue) external;
    function supplyQueueLength() external view returns (uint256);
    function supplyQueue(uint256 index) external view returns (bytes32);
    function reallocate(MarketAllocation[] memory allocations) external;
    
    // User operations
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

// Define minimal interfaces for Morpho components
interface IERC20Mock is IERC20 {
    function setBalance(address account, uint256 amount) external;
}

interface IOracleMock {
    function setPrice(uint256 price) external;
}

interface IIrmMock {}

// Define minimal Morpho interface
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    
    function createMarket(MarketParams calldata marketParams) external returns (bytes32);
    function enableIrm(address irm) external;
    function enableLltv(uint256 lltv) external;
    function supplyShares(bytes32 marketId, address supplier) external view returns (uint256);
}

// Helper library for market params
library MarketParamsLib {
    function id(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            marketParams.loanToken,
            marketParams.collateralToken,
            marketParams.oracle,
            marketParams.irm,
            marketParams.lltv
        ));
    }
}

// Add imports for Pendle oracle contracts
import {PendleSparkLinearDiscountOracleFactory} from "../src/pendle/PendleSparkLinearDiscountOracleFactory.sol";
import {PendleSparkLinearDiscountOracle} from "../src/pendle/PendleSparkLinearDiscountOracle.sol";
import {IPendleSparkLinearDiscountOracleFactory} from "../src/pendle/interfaces/IPendleSparkLinearDiscountOracleFactory.sol";

contract MetaMorphoV1_1Test is Test {
    using MarketParamsLib for IMorpho.MarketParams;

    // Main contracts
    IMorpho public morpho;
    IMetaMorphoV1_1 public metaMorpho;
    
    // Mock tokens and components
    IERC20 public loanToken;
    IERC20Mock public collateralToken;
    IOracleMock public oracle;
    IIrmMock public irm;
    
    // Pendle oracle contracts
    PendleSparkLinearDiscountOracleFactory public pendleOracleFactory;
    PendleSparkLinearDiscountOracle public pendleOracle;
    
    // Test addresses
    address public owner;
    address public curator;
    address public allocator;
    address public user;
    
    // Market parameters
    IMorpho.MarketParams public marketParams;
    bytes32 public marketId;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant SUPPLY_CAP = 500_000e18;
    uint256 public constant LLTV = 0.8e18; // 80% LTV
    uint256 public constant ORACLE_PRICE_SCALE = 1e18;
    
    // Oracle parameters
    uint256 public constant BASE_DISCOUNT_PER_YEAR = 0.05e18; // 5% discount per year
    
    function setUp() public {
        // Create a fork of Ethereum mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        
        // Set up test addresses
        owner = makeAddr("owner");
        curator = makeAddr("curator");
        allocator = makeAddr("allocator");
        user = makeAddr("user");
        
        vm.startPrank(owner);
        
        // Use the real loan token instead of deploying a mock
        loanToken = IERC20(0x21aacE56a8F21210b7E76d8eF1a77253Db85BF0a);
        console.log("Loan Token Address:", address(loanToken));
        
        // Use USDC as collateral token
        collateralToken = IERC20Mock(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        console.log("Collateral Token Address:", address(collateralToken));
        
        // Deploy PendleSparkLinearDiscountOracleFactory
        pendleOracleFactory = new PendleSparkLinearDiscountOracleFactory();
        console.log("Pendle Oracle Factory Address:", address(pendleOracleFactory));
        
        // Create PendleSparkLinearDiscountOracle
        bytes32 salt = bytes32(uint256(1)); // Use a simple salt
        pendleOracle = pendleOracleFactory.createPendleSparkLinearDiscountOracle(
            address(loanToken),
            BASE_DISCOUNT_PER_YEAR,
            salt
        );
        console.log("Pendle Oracle Address:", address(pendleOracle));
        
        // The rest of the setup is commented out for now
        // We'll gradually uncomment and fix parts as we verify each step works
        
        // // Set up mock oracle and IRM
        // oracle = IOracleMock(deployCode("OracleMock.sol"));
        // oracle.setPrice(ORACLE_PRICE_SCALE); // 1:1 price ratio
        
        // irm = IIrmMock(deployCode("IrmMock.sol"));
        
        // // Deploy Morpho
        // morpho = IMorpho(deployCode("Morpho.sol", abi.encode(owner)));
        
        // // Enable IRM and LLTV on Morpho
        // morpho.enableIrm(address(irm));
        // morpho.enableLltv(LLTV);
        
        // // Deploy MetaMorpho vault
        // bytes memory constructorArgs = abi.encode(
        //     owner,
        //     address(morpho),
        //     1 days, // initialTimelock
        //     address(loanToken),
        //     "MetaMorpho Test Vault",
        //     "MTV"
        // );
        // metaMorpho = IMetaMorphoV1_1(deployCode("MetaMorphoV1_1.sol", constructorArgs));
        
        // // Set up roles
        // metaMorpho.setCurator(curator);
        // metaMorpho.setIsAllocator(allocator, true);
        
        vm.stopPrank();
        
        // // Set up market parameters
        // marketParams = IMorpho.MarketParams({
        //     loanToken: address(loanToken),
        //     collateralToken: address(collateralToken),
        //     oracle: address(oracle),
        //     irm: address(irm),
        //     lltv: LLTV
        // });
        
        // marketId = marketParams.id();
        
        // // Create market on Morpho
        // vm.prank(owner);
        // morpho.createMarket(marketParams);
        
        // // Mint tokens to user
        // loanToken.setBalance(user, INITIAL_SUPPLY);
        
        // // Approve MetaMorpho to spend user's tokens
        // vm.prank(user);
        // loanToken.approve(address(metaMorpho), type(uint256).max);
    }
    
    function testAddMarket() public {
        // 1. Submit cap for the market (as curator)
        // vm.prank(curator);
        // metaMorpho.submitCap(convertMarketParams(marketParams), SUPPLY_CAP);
        
        // // Verify market is added to config with correct cap
        // IMetaMorphoV1_1.MarketConfig memory config = metaMorpho.config(marketId);
        // assertEq(config.cap, SUPPLY_CAP, "Market cap should be set correctly");
        // assertEq(config.removableAt, 0, "Market should not be pending removal");
        
        // // 2. Update supply queue (as allocator)
        // bytes32[] memory supplyQueue = new bytes32[](1);
        // supplyQueue[0] = marketId;
        
        // vm.prank(allocator);
        // metaMorpho.setSupplyQueue(supplyQueue);
        
        // // Verify supply queue is updated
        // assertEq(metaMorpho.supplyQueueLength(), 1, "Supply queue should have 1 market");
        // assertEq(metaMorpho.supplyQueue(0), marketId, "Market should be in supply queue");
        
        // // 3. Deposit into the vault
        // uint256 depositAmount = 100_000e18;
        // vm.prank(user);
        // metaMorpho.deposit(depositAmount, user);
        
        // // Verify deposit was successful
        // assertEq(metaMorpho.balanceOf(user), depositAmount, "User should have received shares");
        // assertEq(metaMorpho.totalAssets(), depositAmount, "Total assets should match deposit");
        
        // // Verify funds were supplied to Morpho
        // uint256 morphoSupply = morpho.supplyShares(marketId, address(metaMorpho));
        // assertGt(morphoSupply, 0, "Funds should be supplied to Morpho");
    }
    
    // function testReallocateMarket() public {
    //     // First add the market
    //     vm.prank(curator);
    //     metaMorpho.submitCap(convertMarketParams(marketParams), SUPPLY_CAP);
        
    //     bytes32[] memory supplyQueue = new bytes32[](1);
    //     supplyQueue[0] = marketId;
        
    //     vm.prank(allocator);
    //     metaMorpho.setSupplyQueue(supplyQueue);
        
    //     // Deposit into the vault
    //     uint256 depositAmount = 100_000e18;
    //     vm.prank(user);
    //     metaMorpho.deposit(depositAmount, user);
        
    //     // Create a second market
    //     IERC20Mock newCollateralToken = IERC20Mock(deployCode("ERC20Mock.sol"));
    //     IOracleMock newOracle = IOracleMock(deployCode("OracleMock.sol"));
    //     newOracle.setPrice(ORACLE_PRICE_SCALE);
        
    //     IMorpho.MarketParams memory marketParams2 = IMorpho.MarketParams({
    //         loanToken: address(loanToken),
    //         collateralToken: address(newCollateralToken),
    //         oracle: address(newOracle),
    //         irm: address(irm),
    //         lltv: LLTV
    //     });
        
    //     bytes32 marketId2 = marketParams2.id();
        
    //     vm.prank(owner);
    //     morpho.createMarket(marketParams2);
        
    //     // Add second market to MetaMorpho
    //     vm.prank(curator);
    //     metaMorpho.submitCap(convertMarketParams(marketParams2), SUPPLY_CAP);
        
    //     // Update supply queue to include both markets
    //     bytes32[] memory newSupplyQueue = new bytes32[](2);
    //     newSupplyQueue[0] = marketId;
    //     newSupplyQueue[1] = marketId2;
        
    //     vm.prank(allocator);
    //     metaMorpho.setSupplyQueue(newSupplyQueue);
        
    //     // Reallocate funds between markets
    //     IMetaMorphoV1_1.MarketAllocation[] memory allocations = new IMetaMorphoV1_1.MarketAllocation[](2);
        
    //     allocations[0] = IMetaMorphoV1_1.MarketAllocation({
    //         marketParams: convertMarketParams(marketParams),
    //         assets: depositAmount / 2
    //     });
        
    //     allocations[1] = IMetaMorphoV1_1.MarketAllocation({
    //         marketParams: convertMarketParams(marketParams2),
    //         assets: depositAmount / 2
    //     });
        
    //     vm.prank(allocator);
    //     metaMorpho.reallocate(allocations);
        
    //     // Verify reallocation
    //     uint256 supply1 = morpho.supplyShares(marketId, address(metaMorpho));
    //     uint256 supply2 = morpho.supplyShares(marketId2, address(metaMorpho));
        
    //     assertGt(supply1, 0, "Market 1 should have supply");
    //     assertGt(supply2, 0, "Market 2 should have supply");
    // }
    
    // Helper function to convert between MarketParams types
    function convertMarketParams(IMorpho.MarketParams memory params) 
        internal pure returns (IMetaMorphoV1_1.MarketParams memory) 
    {
        return IMetaMorphoV1_1.MarketParams({
            loanToken: params.loanToken,
            collateralToken: params.collateralToken,
            oracle: params.oracle,
            irm: params.irm,
            lltv: params.lltv
        });
    }

    // Add a simple test to verify we can connect to both tokens
    function testTokenConnections() public {
        // Check loan token
        uint256 loanBalance = loanToken.balanceOf(address(0));
        console.log("Loan token zero address balance:", loanBalance);
        
        try IERC20Metadata(address(loanToken)).name() returns (string memory name) {
            console.log("Loan token name:", name);
        } catch {
            console.log("Loan token name not available");
        }
        
        try IERC20Metadata(address(loanToken)).symbol() returns (string memory symbol) {
            console.log("Loan token symbol:", symbol);
        } catch {
            console.log("Loan token symbol not available");
        }
        
        // Check collateral token (USDC)
        uint256 collateralBalance = collateralToken.balanceOf(address(0));
        console.log("Collateral token zero address balance:", collateralBalance);
        
        try IERC20Metadata(address(collateralToken)).name() returns (string memory name) {
            console.log("Collateral token name:", name);
        } catch {
            console.log("Collateral token name not available");
        }
        
        try IERC20Metadata(address(collateralToken)).symbol() returns (string memory symbol) {
            console.log("Collateral token symbol:", symbol);
        } catch {
            console.log("Collateral token symbol not available");
        }
        
        try IERC20Metadata(address(collateralToken)).decimals() returns (uint8 decimals) {
            console.log("Collateral token decimals:", decimals);
        } catch {
            console.log("Collateral token decimals not available");
        }
        
        // Verify both token contracts exist
        assertTrue(address(loanToken).code.length > 0, "Loan token contract should exist");
        assertTrue(address(collateralToken).code.length > 0, "Collateral token contract should exist");
    }

    // Test the Pendle oracle deployment and functionality
    function testPendleOracle() public {
        // Verify the oracle factory recognizes the oracle
        assertTrue(
            pendleOracleFactory.isPendleSparkLinearDiscountOracle(address(pendleOracle)),
            "Oracle should be recognized by factory"
        );
        
        // Check oracle parameters
        assertEq(pendleOracle.PT(), address(loanToken), "Oracle PT should be loan token");
        assertEq(pendleOracle.baseDiscountPerYear(), BASE_DISCOUNT_PER_YEAR, "Oracle discount rate should match");
        
        // Try to get price data
        try pendleOracle.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            console.log("Oracle round ID:", roundId);
            console.log("Oracle answer:", uint256(answer));
            console.log("Oracle started at:", startedAt);
            console.log("Oracle updated at:", updatedAt);
            console.log("Oracle answered in round:", answeredInRound);
        } catch Error(string memory reason) {
            console.log("Oracle error:", reason);
        } catch {
            console.log("Oracle call failed with unknown error");
        }
        
        // Check oracle decimals
        assertEq(pendleOracle.decimals(), 18, "Oracle decimals should be 18");
    }
}
