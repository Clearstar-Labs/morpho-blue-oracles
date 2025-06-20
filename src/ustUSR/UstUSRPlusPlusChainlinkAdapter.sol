// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {MinimalAggregatorV3Interface} from "../fxusd-nav-adapter/interfaces/MinimalAggregatorV3Interface.sol";

/// @title IUSRPriceAggregatorV3Interface
/// @notice Interface for the USR Price Aggregator with only the required functions
interface IUSRPriceAggregatorV3Interface {
    /// @notice Returns the number of decimals for the price feed
    function decimals() external view returns (uint8);
    
    /// @notice Returns the latest round data from the price feed
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/// @title UstUSRPlusPlusChainlinkAdapter
/// @author Clearstar Labs
/// @notice ustUSR++ price feed adapter that implements the Chainlink AggregatorV3Interface.
/// @dev This contract should only be deployed on Ethereum and used as a price feed for Morpho oracles.
contract UstUSRPlusPlusChainlinkAdapter is MinimalAggregatorV3Interface {
    /// @inheritdoc MinimalAggregatorV3Interface
    /// @dev The calculated price has 18 decimals precision, whatever the value of `decimals`.
    uint8 public constant decimals = 18;

    /// @notice The description of the price feed.
    string public constant description = "ustUSR++ USD price";

    /// @notice The address of the USRPriceAggregatorV3Interface on Ethereum.
    IUSRPriceAggregatorV3Interface public immutable usrPriceAggregator;

    /// @notice Constructor to set the USRPriceAggregatorV3Interface address.
    /// @param _usrPriceAggregator The address of the USRPriceAggregatorV3Interface contract.
    constructor(IUSRPriceAggregatorV3Interface _usrPriceAggregator) {
        if (address(_usrPriceAggregator) == address(0)) revert ZeroAddress();
        usrPriceAggregator = _usrPriceAggregator;
    }

    /// @inheritdoc MinimalAggregatorV3Interface
    /// @dev Returns zero for roundId, startedAt, and answeredInRound. 
    /// @dev Returns the timestamp from the USR price feed for updatedAt.
    /// @dev Converts the USR price from 8 decimals to 18 decimals.
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // Get the latest price data from the USR price feed
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = 
            usrPriceAggregator.latestRoundData();
        
        // Convert the price from 8 decimals to 18 decimals
        // USRPriceAggregatorV3Interface returns price with 8 decimals
        int256 adjustedAnswer = answer * int256(10 ** (decimals - usrPriceAggregator.decimals()));
        
        // Return the data with our roundId, startedAt, and answeredInRound as 0
        // but keep the updatedAt from the original feed
        return (0, adjustedAnswer, 0, updatedAt, 0);
    }
    
    /// @dev Custom error for zero address input
    error ZeroAddress();
}
