// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IReputationRegistry
 * @dev Simple reputation system with up/down votes
 */
interface IReputationRegistry {
    // ============ Events ============

    event ReputationChanged(
        uint256 indexed agentId,
        address indexed voter,
        bool isPositive,
        int256 newScore
    );

    // ============ Errors ============

    error AgentNotFound();
    error AlreadyVoted();

    // ============ Write Functions ============

    /**
     * @dev Vote positively for an agent (increases reputation)
     * @param agentId The agent to vote for
     */
    function voteUp(uint256 agentId) external;

    /**
     * @dev Vote negatively for an agent (decreases reputation)
     * @param agentId The agent to vote against
     */
    function voteDown(uint256 agentId) external;

    // ============ Read Functions ============

    /**
     * @dev Get an agent's reputation score
     * @param agentId The agent ID
     * @return score The reputation score (can be negative)
     */
    function getReputation(uint256 agentId) external view returns (int256 score);

    /**
     * @dev Get vote counts for an agent
     * @param agentId The agent ID
     * @return upVotes Number of positive votes
     * @return downVotes Number of negative votes
     */
    function getVoteCounts(uint256 agentId) external view returns (uint256 upVotes, uint256 downVotes);

    /**
     * @dev Check if an address has voted for an agent
     * @param agentId The agent ID
     * @param voter The voter address
     * @return hasVoted True if already voted
     */
    function hasVoted(uint256 agentId, address voter) external view returns (bool hasVoted);
}
