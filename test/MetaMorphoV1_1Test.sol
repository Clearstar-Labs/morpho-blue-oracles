// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IOracle} from "lib/morpho-blue/src/interfaces/IOracle.sol";

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
    function owner() external view returns (address);
    function curator() external view returns (address);
    function isAllocator(address allocator) external view returns (bool);
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
    
    function owner() external view returns (address);
    function isIrmEnabled(address irm) external view returns (bool);
    function isLltvEnabled(uint256 lltv) external view returns (bool);
    function createMarket(MarketParams calldata marketParams) external returns (bytes32);
    function enableIrm(address irm) external;
    function enableLltv(uint256 lltv) external;
    function supplyShares(bytes32 marketId, address supplier) external view returns (uint256);
}

library MarketParamsLib {
    /// @notice The length of the data used to compute the id of a market.
    /// @dev The length is 5 * 32 because `MarketParams` has 5 variables of 32 bytes each.
    uint256 internal constant MARKET_PARAMS_BYTES_LENGTH = 5 * 32;

    /// @notice Returns the id of the market `marketParams`.
    function id(IMorpho.MarketParams memory marketParams) internal pure returns (bytes32 marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(marketParams, MARKET_PARAMS_BYTES_LENGTH)
        }
    }
}

// Add imports for Pendle oracle contracts
import {PendleSparkLinearDiscountOracleFactory} from "../src/pendle/PendleSparkLinearDiscountOracleFactory.sol";
import {PendleSparkLinearDiscountOracle} from "../src/pendle/PendleSparkLinearDiscountOracle.sol";
import {IPendleSparkLinearDiscountOracleFactory} from "../src/pendle/interfaces/IPendleSparkLinearDiscountOracleFactory.sol";

// Add imports for Morpho Chainlink oracle contracts
import {MorphoChainlinkOracleV2Factory} from "../src/morpho-chainlink/MorphoChainlinkOracleV2Factory.sol";
import {MorphoChainlinkOracleV2} from "../src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import {IMorphoChainlinkOracleV2Factory} from "../src/morpho-chainlink/interfaces/IMorphoChainlinkOracleV2Factory.sol";
import {AggregatorV3Interface} from "../src/morpho-chainlink/libraries/ChainlinkDataFeedLib.sol";
import {IERC4626} from "../src/morpho-chainlink/libraries/VaultLib.sol";

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

    // Morpho Chainlink oracle contracts
    MorphoChainlinkOracleV2Factory public chainlinkOracleFactory;
    MorphoChainlinkOracleV2 public chainlinkOracle;
    
    // Test addresses
    address public metaMorphoOwner;
    address public morphoOwner;
    address public curator;
    address public allocator;
    address public user;
    
    // Market parameters
    IMorpho.MarketParams public marketParams;
    bytes32 public marketId;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant SUPPLY_CAP = 500_000e18;
    uint256 public constant LLTV = 0.77e18; // 77% LTV
    uint256 public constant ORACLE_PRICE_SCALE = 1e18;
    
    // Oracle parameters
    uint256 public constant BASE_DISCOUNT_PER_YEAR = 0.05e18; // 5% discount per year
    
    function setUp() public {
        // Create a fork of Ethereum mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        
        // Set up test addresses
        metaMorphoOwner = address(0x30988479C2E6a03E7fB65138b94762D41a733458); // Real owner of MetaMorpho
        morphoOwner = address(0xcBa28b38103307Ec8dA98377ffF9816C164f9AFa); // Real owner of Morpho
        curator = address(0x72882eb5D27C7088DFA6DDE941DD42e5d184F0ef); // Real curator
        allocator = makeAddr("allocator");
        user = makeAddr("user");
        
        // Use USDC as loan token
        loanToken = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        console.log("Loan Token Address:", address(loanToken));
        
        // Use PT fxSAVE as collateral token
        // PT fxSAVE address
        collateralToken = IERC20Mock(0x21aacE56a8F21210b7E76d8eF1a77253Db85BF0a); // PT fxSAVE
        console.log("Collateral Token Address:", address(collateralToken));
        
        // Deploy PendleSparkLinearDiscountOracleFactory
        pendleOracleFactory = new PendleSparkLinearDiscountOracleFactory();
        console.log("Pendle Oracle Factory Address:", address(pendleOracleFactory));
        
        // Create PendleSparkLinearDiscountOracle for PT fxSAVE
        bytes32 salt = bytes32(uint256(1)); // Use a simple salt
        pendleOracle = pendleOracleFactory.createPendleSparkLinearDiscountOracle(
            address(collateralToken),
            BASE_DISCOUNT_PER_YEAR,
            salt
        );
        console.log("Pendle Oracle Address:", address(pendleOracle));
        
        // Use existing MorphoChainlinkOracleV2Factory
        chainlinkOracleFactory = MorphoChainlinkOracleV2Factory(0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766);
        console.log("Chainlink Oracle Factory Address:", address(chainlinkOracleFactory));
        
        // Create MorphoChainlinkOracleV2 using the Pendle oracle as a feed
        // For PT fxSAVE/USDC pair
        bytes32 chainlinkSalt = bytes32(uint256(2)); // Different salt
        
        // Use USDC/USD feed for the quote token (loan token)
        AggregatorV3Interface usdcUsdFeed = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        
        // Use existing Morpho contract
        morpho = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
        console.log("Morpho Address:", address(morpho));
        
        // Use existing Adaptive Curve IRM
        irm = IIrmMock(0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC);
        console.log("IRM Address:", address(irm));
        
        // Use existing MetaMorpho vault
        metaMorpho = IMetaMorphoV1_1(0x62fE596d59fB077c2Df736dF212E0AFfb522dC78);
        console.log("MetaMorpho Vault Address:", address(metaMorpho));
        
        // Set up allocator role (curator is already set)
        vm.prank(metaMorphoOwner);
        metaMorpho.setIsAllocator(allocator, true);
        
        // Enable LLTV on Morpho if not already enabled
        console.log("Morpho Owner:", morphoOwner);
        
        vm.prank(morphoOwner);
        if (!morpho.isLltvEnabled(LLTV)) {
            morpho.enableLltv(LLTV);
        }


        // Create the oracle with PT fxSAVE as base (collateral) and USDC as quote (loan)
        chainlinkOracle = chainlinkOracleFactory.createMorphoChainlinkOracleV2(
            IERC4626(address(0)), // No vault for PT fxSAVE
            1, // No conversion needed
            AggregatorV3Interface(address(pendleOracle)), // Use Pendle oracle as the feed for PT fxSAVE
            AggregatorV3Interface(address(0)), // No second feed
            18, // PT fxSAVE has 18 decimals
            IERC4626(address(0)), // No vault for USDC
            1, // No conversion needed
            usdcUsdFeed, // USDC/USD feed
            AggregatorV3Interface(address(0)), // No second feed
            6, // USDC has 6 decimals
            chainlinkSalt
        );
        console.log("Chainlink Oracle Address:", address(chainlinkOracle));

        uint256 price = IOracle(address(chainlinkOracle)).price();
        console.log("price:", price);
        // Check if the oracle works by getting its price
        // try IOracle(address(chainlinkOracle)).price() returns (uint256 price) {
        //     console.log("Oracle price:", price);
        //     console.log("Oracle price (normalized):", price / 1e36);
        // } catch Error(string memory reason) {
        //     console.log("Oracle error:", reason);
        // } catch {
        //     console.log("Oracle call failed with unknown error");
        // }

        // // Check the Pendle oracle feed
        // try AggregatorV3Interface(address(pendleOracle)).latestRoundData() returns (
        //     uint80 roundId,
        //     int256 answer,
        //     uint256 startedAt,
        //     uint256 updatedAt,
        //     uint80 answeredInRound
        // ) {
        //     console.log("Pendle oracle answer:", uint256(answer));
        // } catch Error(string memory reason) {
        //     console.log("Pendle oracle error:", reason);
        // } catch {
        //     console.log("Pendle oracle call failed with unknown error");
        // }

        // // Check the USDC/USD feed
        // try usdcUsdFeed.latestRoundData() returns (
        //     uint80 roundId,
        //     int256 answer,
        //     uint256 startedAt,
        //     uint256 updatedAt,
        //     uint80 answeredInRound
        // ) {
        //     console.log("USDC/USD feed answer:", uint256(answer));
        // } catch Error(string memory reason) {
        //     console.log("USDC/USD feed error:", reason);
        // } catch {
        //     console.log("USDC/USD feed call failed with unknown error");
        // }
        
        // // Set up market parameters using the Chainlink oracle
        // marketParams = IMorpho.MarketParams({
        //     loanToken: address(loanToken),
        //     collateralToken: address(collateralToken),
        //     oracle: address(chainlinkOracle), // Use the Chainlink oracle
        //     irm: address(irm),
        //     lltv: LLTV
        // });
        
        // marketId = marketParams.id();

        // console.logBytes32(marketId);
        
        // Create market on Morpho
        // vm.prank(morphoOwner);
        // try morpho.createMarket(marketParams) {
        //     console.log("Market created successfully with ID:", bytes32ToString(marketId));
        // } catch Error(string memory reason) {
        //     console.log("Failed to create market:", reason);
        //     // Check if market already exists by trying to get some data from it
        //     // try morpho.supplyShares(marketId, address(0)) {
        //     //     console.log("Market already exists, continuing...");
        //     // } catch {
        //     //     // If market doesn't exist and we couldn't create it, make sure IRM is enabled
        //     //     vm.prank(morphoOwner);
        //     //     morpho.enableIrm(address(irm));
                
        //     //     // Try again after enabling IRM
        //     //     vm.prank(morphoOwner);
        //     //     morpho.createMarket(marketParams);
        //     // }
        // }
        
        // // Mint tokens to user
        // vm.startPrank(address(0));
        // IERC20Mock(address(loanToken)).setBalance(user, INITIAL_SUPPLY);
        // vm.stopPrank();
        
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
        assertEq(pendleOracle.PT(), address(collateralToken), "Oracle PT should be loan token");
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

    // Test the Morpho and IRM connections
    function testMorphoAndIrmConnections() public {
        // Verify Morpho contract exists
        assertTrue(address(morpho).code.length > 0, "Morpho contract should exist");
        
        // Verify IRM contract exists
        assertTrue(address(irm).code.length > 0, "IRM contract should exist");
        
        // Try to get Morpho owner
        try IMorpho(address(morpho)).owner() returns (address currentMorphoOwner) {
            console.log("Morpho owner:", currentMorphoOwner);
            assertEq(currentMorphoOwner, morphoOwner, "Morpho owner should match");
        } catch {
            console.log("Failed to get Morpho owner");
        }
        
        // Check if IRM is enabled on Morpho
        try IMorpho(address(morpho)).isIrmEnabled(address(irm)) returns (bool isEnabled) {
            console.log("IRM enabled on Morpho:", isEnabled);
        } catch {
            console.log("Failed to check if IRM is enabled");
        }
    }

    // Test the MetaMorpho vault setup
    function testMetaMorphoSetup() public {
        // Verify MetaMorpho contract exists
        assertTrue(address(metaMorpho).code.length > 0, "MetaMorpho contract should exist");
        
        // Check if curator is set correctly
        try metaMorpho.curator() returns (address currentCurator) {
            console.log("MetaMorpho curator:", currentCurator);
            assertEq(currentCurator, curator, "Curator should be set correctly");
        } catch {
            console.log("Failed to get MetaMorpho curator");
        }
        
        // Check if allocator is set correctly
        try metaMorpho.isAllocator(allocator) returns (bool isAllocator) {
            console.log("Is allocator:", isAllocator);
            assertTrue(isAllocator, "Allocator should be set correctly");
        } catch {
            console.log("Failed to check if allocator is set");
        }
        
        // Try to get owner
        try IMetaMorphoV1_1(address(metaMorpho)).owner() returns (address currentMetaMorphoOwner) {
            console.log("MetaMorpho owner:", currentMetaMorphoOwner);
            assertEq(currentMetaMorphoOwner, metaMorphoOwner, "Owner should match");
        } catch {
            console.log("Failed to get MetaMorpho owner");
        }
    }

    // Helper function to convert bytes32 to string for logging
    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            uint8 value = uint8(uint256(_bytes32) / (2**(8 * (31 - i))));
            uint8 hi = value / 16;
            uint8 lo = value - 16 * hi;
            
            // Convert to hex characters (0-9, a-f)
            bytesArray[i * 2] = hi < 10 ? bytes1(uint8(48 + hi)) : bytes1(uint8(87 + hi)); // 48 is '0', 87 is 'a'-10
            bytesArray[i * 2 + 1] = lo < 10 ? bytes1(uint8(48 + lo)) : bytes1(uint8(87 + lo));
        }
        return string(bytesArray);
    }
}
