// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

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
interface IERC20Mock {
    function approve(address spender, uint256 amount) external returns (bool);
    function setBalance(address account, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
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

contract MetaMorphoV1_1Test is Test {
    using MarketParamsLib for IMorpho.MarketParams;

    // Main contracts
    IMorpho public morpho;
    IMetaMorphoV1_1 public metaMorpho;
    
    // Mock tokens and components
    IERC20Mock public loanToken;
    IERC20Mock public collateralToken;
    IOracleMock public oracle;
    IIrmMock public irm;
    
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
    
    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        curator = makeAddr("curator");
        allocator = makeAddr("allocator");
        user = makeAddr("user");
        
        vm.startPrank(owner);
        
        // Deploy mock tokens
        loanToken = IERC20Mock(deployCode("ERC20Mock.sol"));
        collateralToken = IERC20Mock(deployCode("ERC20Mock.sol"));
        
        // Set up mock oracle and IRM
        oracle = IOracleMock(deployCode("OracleMock.sol"));
        oracle.setPrice(ORACLE_PRICE_SCALE); // 1:1 price ratio
        
        irm = IIrmMock(deployCode("IrmMock.sol"));
        
        // Deploy Morpho
        morpho = IMorpho(deployCode("Morpho.sol", abi.encode(owner)));
        
        // Enable IRM and LLTV on Morpho
        morpho.enableIrm(address(irm));
        morpho.enableLltv(LLTV);
        
        // Deploy MetaMorpho vault
        bytes memory constructorArgs = abi.encode(
            owner,
            address(morpho),
            1 days, // initialTimelock
            address(loanToken),
            "MetaMorpho Test Vault",
            "MTV"
        );
        metaMorpho = IMetaMorphoV1_1(deployCode("MetaMorphoV1_1.sol", constructorArgs));
        
        // Set up roles
        metaMorpho.setCurator(curator);
        metaMorpho.setIsAllocator(allocator, true);
        
        vm.stopPrank();
        
        // Set up market parameters
        marketParams = IMorpho.MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(oracle),
            irm: address(irm),
            lltv: LLTV
        });
        
        marketId = marketParams.id();
        
        // Create market on Morpho
        vm.prank(owner);
        morpho.createMarket(marketParams);
        
        // Mint tokens to user
        loanToken.setBalance(user, INITIAL_SUPPLY);
        
        // Approve MetaMorpho to spend user's tokens
        vm.prank(user);
        loanToken.approve(address(metaMorpho), type(uint256).max);
    }
    
    function testAddMarket() public {
        // 1. Submit cap for the market (as curator)
        vm.prank(curator);
        metaMorpho.submitCap(convertMarketParams(marketParams), SUPPLY_CAP);
        
        // Verify market is added to config with correct cap
        IMetaMorphoV1_1.MarketConfig memory config = metaMorpho.config(marketId);
        assertEq(config.cap, SUPPLY_CAP, "Market cap should be set correctly");
        assertEq(config.removableAt, 0, "Market should not be pending removal");
        
        // 2. Update supply queue (as allocator)
        bytes32[] memory supplyQueue = new bytes32[](1);
        supplyQueue[0] = marketId;
        
        vm.prank(allocator);
        metaMorpho.setSupplyQueue(supplyQueue);
        
        // Verify supply queue is updated
        assertEq(metaMorpho.supplyQueueLength(), 1, "Supply queue should have 1 market");
        assertEq(metaMorpho.supplyQueue(0), marketId, "Market should be in supply queue");
        
        // 3. Deposit into the vault
        uint256 depositAmount = 100_000e18;
        vm.prank(user);
        metaMorpho.deposit(depositAmount, user);
        
        // Verify deposit was successful
        assertEq(metaMorpho.balanceOf(user), depositAmount, "User should have received shares");
        assertEq(metaMorpho.totalAssets(), depositAmount, "Total assets should match deposit");
        
        // Verify funds were supplied to Morpho
        uint256 morphoSupply = morpho.supplyShares(marketId, address(metaMorpho));
        assertGt(morphoSupply, 0, "Funds should be supplied to Morpho");
    }
    
    function testReallocateMarket() public {
        // First add the market
        vm.prank(curator);
        metaMorpho.submitCap(convertMarketParams(marketParams), SUPPLY_CAP);
        
        bytes32[] memory supplyQueue = new bytes32[](1);
        supplyQueue[0] = marketId;
        
        vm.prank(allocator);
        metaMorpho.setSupplyQueue(supplyQueue);
        
        // Deposit into the vault
        uint256 depositAmount = 100_000e18;
        vm.prank(user);
        metaMorpho.deposit(depositAmount, user);
        
        // Create a second market
        IERC20Mock newCollateralToken = IERC20Mock(deployCode("ERC20Mock.sol"));
        IOracleMock newOracle = IOracleMock(deployCode("OracleMock.sol"));
        newOracle.setPrice(ORACLE_PRICE_SCALE);
        
        IMorpho.MarketParams memory marketParams2 = IMorpho.MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(newCollateralToken),
            oracle: address(newOracle),
            irm: address(irm),
            lltv: LLTV
        });
        
        bytes32 marketId2 = marketParams2.id();
        
        vm.prank(owner);
        morpho.createMarket(marketParams2);
        
        // Add second market to MetaMorpho
        vm.prank(curator);
        metaMorpho.submitCap(convertMarketParams(marketParams2), SUPPLY_CAP);
        
        // Update supply queue to include both markets
        bytes32[] memory newSupplyQueue = new bytes32[](2);
        newSupplyQueue[0] = marketId;
        newSupplyQueue[1] = marketId2;
        
        vm.prank(allocator);
        metaMorpho.setSupplyQueue(newSupplyQueue);
        
        // Reallocate funds between markets
        IMetaMorphoV1_1.MarketAllocation[] memory allocations = new IMetaMorphoV1_1.MarketAllocation[](2);
        
        allocations[0] = IMetaMorphoV1_1.MarketAllocation({
            marketParams: convertMarketParams(marketParams),
            assets: depositAmount / 2
        });
        
        allocations[1] = IMetaMorphoV1_1.MarketAllocation({
            marketParams: convertMarketParams(marketParams2),
            assets: depositAmount / 2
        });
        
        vm.prank(allocator);
        metaMorpho.reallocate(allocations);
        
        // Verify reallocation
        uint256 supply1 = morpho.supplyShares(marketId, address(metaMorpho));
        uint256 supply2 = morpho.supplyShares(marketId2, address(metaMorpho));
        
        assertGt(supply1, 0, "Market 1 should have supply");
        assertGt(supply2, 0, "Market 2 should have supply");
    }
    
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
}
