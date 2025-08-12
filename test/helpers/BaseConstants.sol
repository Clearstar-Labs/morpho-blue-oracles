// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC4626} from "../../src/morpho-chainlink/interfaces/IERC4626.sol";
import {AggregatorV3Interface} from "../../src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";

// Base network constants (Chain ID: 8453)

// Common constants
AggregatorV3Interface constant feedZero = AggregatorV3Interface(address(0));
IERC4626 constant vaultZero = IERC4626(address(0));

// Existing MorphoChainlinkOracleV2Factory on Base
address constant BASE_MORPHO_FACTORY = 0x2DC205F24BCb6B311E5cdf0745B0741648Aebd3d;

// Base network oracle feeds
// Note: Replace placeholder addresses with your actual deployed oracle addresses

// USDC/USD feed on Base - 8 decimals
// This is the actual Chainlink USDC/USD feed on Base
AggregatorV3Interface constant baseUsdcUsdFeed = AggregatorV3Interface(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B);

// USR/USD feed on Base - 8 decimals (Chainlink)
AggregatorV3Interface constant baseUsrUsdFeed = AggregatorV3Interface(0x4a595E0a62E50A2E5eC95A70c8E612F9746af006);

// WSTUSR/USR Pyth oracle (Chainlink compatible) - 8 decimals (typical for Pyth)
AggregatorV3Interface constant baseWstUsrUsrFeed = AggregatorV3Interface(0x17D099fc623bd06CFE4861d874704Af184773c75);

// Token decimals on Base
uint256 constant WSTUSR_DECIMALS = 18; // wstUSR has 18 decimals
uint256 constant USDC_DECIMALS = 6;    // USDC has 6 decimals on Base

// Correct wstUSR token address on Base
address constant WSTUSR_TOKEN = 0xB67675158B412D53fe6B68946483ba920b135bA1;
