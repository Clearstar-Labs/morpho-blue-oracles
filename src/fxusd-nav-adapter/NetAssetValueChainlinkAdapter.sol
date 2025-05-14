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

    constructor(INetAssetValue _token) {
        token = _token;
    }

    /// @inheritdoc MinimalAggregatorV3Interface
    /// @dev Returns zero for roundId, startedAt, updatedAt and answeredInRound.
    /// @dev Silently overflows if `nav`'s return value is greater than `type(int256).max`.
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // It is assumed that `token.nav()` returns a usd price with 18 decimals precision.
        return (0, int256(token.nav()), 0, 0, 0);
    }
}