// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IValidationRegistry
 * @dev Simple validation system where validators submit scores for agents
 */
interface IValidationRegistry {
    // ============ Events ============

    event ValidationSubmitted(
        uint256 indexed agentId,
        address indexed validator,
        uint8 score,
        string dataUri
    );

    // ============ Errors ============

    error AgentNotFound();
    error InvalidScore();
    error AlreadyValidated();

    // ============ Write Functions ============

    /**
     * @dev Submit a validation score for an agent
     * @param agentId The agent being validated
     * @param score Validation score (0-100)
     * @param dataUri Optional URI with validation details
     */
    function submitValidation(uint256 agentId, uint8 score, string calldata dataUri) external;

    // ============ Read Functions ============

    /**
     * @dev Get aggregated validation data for an agent
     * @param agentId The agent ID
     * @return validationCount Number of validations
     * @return averageScore Average validation score (0-100)
     */
    function getValidation(uint256 agentId) external view returns (uint256 validationCount, uint8 averageScore);

    /**
     * @dev Check if a validator has already validated an agent
     * @param agentId The agent ID
     * @param validator The validator address
     * @return hasValidated True if already validated
     */
    function hasValidated(uint256 agentId, address validator) external view returns (bool hasValidated);
}
