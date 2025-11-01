// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IValidationRegistry.sol";
import "./interfaces/IIdentityRegistry.sol";

/**
 * @title ValidationRegistry
 * @dev Simple validation system with score aggregation
 * @author ChaosChain Labs
 */
contract ValidationRegistry is IValidationRegistry {
    // ============ State Variables ============

    /// @dev Reference to the IdentityRegistry for agent validation
    IIdentityRegistry public immutable identityRegistry;

    /// @dev Mapping from agent ID to total validation score sum
    mapping(uint256 => uint256) private _totalScores;

    /// @dev Mapping from agent ID to validation count
    mapping(uint256 => uint256) private _validationCounts;

    /// @dev Mapping from agent ID to validator address to whether they validated
    mapping(uint256 => mapping(address => bool)) private _hasValidated;

    // ============ Constructor ============

    /**
     * @dev Constructor sets the identity registry reference
     * @param _identityRegistry Address of the IdentityRegistry contract
     */
    constructor(address _identityRegistry) {
        identityRegistry = IIdentityRegistry(_identityRegistry);
    }

    // ============ Write Functions ============

    /**
     * @inheritdoc IValidationRegistry
     */
    function submitValidation(uint256 agentId, uint8 score, string calldata dataUri) external {
        // Validate agent exists
        if (!identityRegistry.agentExists(agentId)) {
            revert AgentNotFound();
        }

        // Validate score range
        if (score > 100) {
            revert InvalidScore();
        }

        // Check if already validated
        if (_hasValidated[agentId][msg.sender]) {
            revert AlreadyValidated();
        }

        // Mark as validated
        _hasValidated[agentId][msg.sender] = true;

        // Update aggregated scores
        _totalScores[agentId] += score;
        _validationCounts[agentId]++;

        emit ValidationSubmitted(agentId, msg.sender, score, dataUri);
    }

    // ============ Read Functions ============

    /**
     * @inheritdoc IValidationRegistry
     */
    function getValidation(uint256 agentId) external view returns (uint256 validationCount, uint8 averageScore) {
        validationCount = _validationCounts[agentId];
        if (validationCount > 0) {
            averageScore = uint8(_totalScores[agentId] / validationCount);
        }
        return (validationCount, averageScore);
    }

    /**
     * @inheritdoc IValidationRegistry
     */
    function hasValidated(uint256 agentId, address validator) external view returns (bool) {
        return _hasValidated[agentId][validator];
    }

    /**
     * @dev Get the identity registry address
     */
    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }
}
