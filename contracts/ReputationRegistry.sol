// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IReputationRegistry.sol";
import "./interfaces/IIdentityRegistry.sol";

/**
 * @title ReputationRegistry
 * @dev Simple reputation system with up/down voting
 * @author ChaosChain Labs
 */
contract ReputationRegistry is IReputationRegistry {
    // ============ State Variables ============

    /// @dev Reference to the IdentityRegistry for agent validation
    IIdentityRegistry public immutable identityRegistry;

    /// @dev Mapping from agent ID to reputation score
    mapping(uint256 => int256) private _reputationScores;

    /// @dev Mapping from agent ID to up vote count
    mapping(uint256 => uint256) private _upVotes;

    /// @dev Mapping from agent ID to down vote count
    mapping(uint256 => uint256) private _downVotes;

    /// @dev Mapping from agent ID to voter address to whether they voted
    mapping(uint256 => mapping(address => bool)) private _hasVoted;

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
     * @inheritdoc IReputationRegistry
     */
    function voteUp(uint256 agentId) external {
        // Validate agent exists
        if (!identityRegistry.agentExists(agentId)) {
            revert AgentNotFound();
        }

        // Check if already voted
        if (_hasVoted[agentId][msg.sender]) {
            revert AlreadyVoted();
        }

        // Mark as voted
        _hasVoted[agentId][msg.sender] = true;

        // Increment vote counts
        _upVotes[agentId]++;
        _reputationScores[agentId]++;

        emit ReputationChanged(agentId, msg.sender, true, _reputationScores[agentId]);
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function voteDown(uint256 agentId) external {
        // Validate agent exists
        if (!identityRegistry.agentExists(agentId)) {
            revert AgentNotFound();
        }

        // Check if already voted
        if (_hasVoted[agentId][msg.sender]) {
            revert AlreadyVoted();
        }

        // Mark as voted
        _hasVoted[agentId][msg.sender] = true;

        // Increment vote counts
        _downVotes[agentId]++;
        _reputationScores[agentId]--;

        emit ReputationChanged(agentId, msg.sender, false, _reputationScores[agentId]);
    }

    // ============ Read Functions ============

    /**
     * @inheritdoc IReputationRegistry
     */
    function getReputation(uint256 agentId) external view returns (int256 score) {
        return _reputationScores[agentId];
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function getVoteCounts(uint256 agentId) external view returns (uint256 upVotes, uint256 downVotes) {
        return (_upVotes[agentId], _downVotes[agentId]);
    }

    /**
     * @inheritdoc IReputationRegistry
     */
    function hasVoted(uint256 agentId, address voter) external view returns (bool) {
        return _hasVoted[agentId][voter];
    }

    /**
     * @dev Get the identity registry address
     */
    function getIdentityRegistry() external view returns (address) {
        return address(identityRegistry);
    }
}
