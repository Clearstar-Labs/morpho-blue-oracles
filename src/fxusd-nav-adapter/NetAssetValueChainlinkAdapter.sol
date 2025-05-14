// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {MinimalAggregatorV3Interface} from "./interfaces/MinimalAggregatorV3Interface.sol";

interface INetAssetValue {
    /// @notice Return the nav of token.
    function nav() external view returns (uint256);
}

/// @title NetAssetValueChainlinkAdapter
/// @author Aladdin DAO
/// @custom:contact security@morpho.org
/// @notice Net asset value USD price feed.
/// @dev This contract should only be deployed on Ethereum and used as a price feed for Morpho oracles.
contract NetAssetValueChainlinkAdapter is MinimalAggregatorV3Interface {
    /// @inheritdoc MinimalAggregatorV3Interface
    // @dev The calculated price has 18 decimals precision, whatever the value of `decimals`.
    uint8 public constant decimals = 18;

    /// @notice The description of the price feed.
    string public constant description = "Net Asset Value in USD";

    /// @notice The address of token on Ethereum.
    INetAssetValue public immutable token;
    
    /// @notice The maximum cap for the NAV value.
    uint256 public immutable maxCap;

    constructor(INetAssetValue _token, uint256 _maxCap) {
        token = _token;
        maxCap = _maxCap;
        
        // Ensure the current NAV is less than the max cap
        require(token.nav() <= _maxCap, "Initial NAV exceeds max cap");
    }

    /// @inheritdoc MinimalAggregatorV3Interface
    /// @dev Returns zero for roundId, startedAt, updatedAt and answeredInRound.
    /// @dev Silently overflows if `nav`'s return value is greater than `type(int256).max`.
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // Get the current NAV value
        uint256 navValue = token.nav();
        
        // Cap the NAV value if it exceeds the maximum
        if (navValue > maxCap) {
            navValue = maxCap;
        }
        
        // It is assumed that `token.nav()` returns a usd price with 18 decimals precision.
        return (0, int256(navValue), 0, 0, 0);
    }
}
