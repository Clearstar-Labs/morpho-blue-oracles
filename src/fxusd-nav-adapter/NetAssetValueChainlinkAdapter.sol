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
    uint256 public maxCap;
    
    /// @notice The address authorized to update the maxCap.
    address public admin;
    
    /// @notice The proposed new maxCap value.
    uint256 public proposedMaxCap;
    
    /// @notice The timestamp when the proposed maxCap can be applied.
    uint256 public proposedMaxCapTimestamp;
    
    /// @notice The timelock duration in seconds.
    uint256 public constant TIMELOCK_DURATION = 2 days;
    
    /// @notice Emitted when a new maxCap is proposed.
    event MaxCapProposed(uint256 currentMaxCap, uint256 proposedMaxCap, uint256 effectiveTimestamp);
    
    /// @notice Emitted when a new maxCap is applied.
    event MaxCapUpdated(uint256 oldMaxCap, uint256 newMaxCap);

    constructor(INetAssetValue _token, uint256 _maxCap, address _admin) {
        token = _token;
        
        // Get the current NAV
        uint256 currentNav = _token.nav();
        
        // Ensure the max cap is not too high (max 50% above current NAV)
        require(_maxCap <= currentNav * 3 / 2, "Max cap too high");
        
        // Ensure the max cap is at least 5% above current NAV
        require(_maxCap >= currentNav * 105 / 100, "Max cap too low");
        
        maxCap = _maxCap;
        admin = _admin;
    }
    
    /// @notice Proposes a new maxCap value.
    /// @param _newMaxCap The proposed new maxCap value.
    function proposeMaxCap(uint256 _newMaxCap) external {
        require(msg.sender == admin, "Only admin can propose");
        
        // Get the current NAV
        uint256 currentNav = token.nav();
        
        // Ensure the new max cap is not too high (max 50% above current NAV)
        require(_newMaxCap <= currentNav * 3 / 2, "Max cap too high");
        
        // Ensure the new max cap is at least 5% above current NAV
        require(_newMaxCap >= currentNav * 105 / 100, "Max cap too low");
        
        proposedMaxCap = _newMaxCap;
        proposedMaxCapTimestamp = block.timestamp + TIMELOCK_DURATION;
        
        emit MaxCapProposed(maxCap, _newMaxCap, proposedMaxCapTimestamp);
    }
    
    /// @notice Applies the proposed maxCap after the timelock period.
    function applyMaxCap() external {
        require(proposedMaxCap > 0, "No proposed max cap");
        require(block.timestamp >= proposedMaxCapTimestamp, "Timelock not expired");
        
        uint256 oldMaxCap = maxCap;
        maxCap = proposedMaxCap;
        
        // Reset the proposal
        proposedMaxCap = 0;
        proposedMaxCapTimestamp = 0;
        
        emit MaxCapUpdated(oldMaxCap, maxCap);
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
