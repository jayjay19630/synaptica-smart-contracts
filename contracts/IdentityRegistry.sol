// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IIdentityRegistry.sol";
import "./interfaces/IReputationRegistry.sol";
import "./interfaces/IValidationRegistry.sol";

/**
 * @title IdentityRegistry
 * @dev Implementation of the Identity Registry for ERC-XXXX Trustless Agents v0.3
 * @notice Central registry for all agent identities with spam protection
 * @author ChaosChain Labs
 */
contract IdentityRegistry is IIdentityRegistry {
    // ============ Constants ============

    /// @dev Registration fee of 0.005 ETH that gets burned
    uint256 public constant REGISTRATION_FEE = 0.005 ether;

    // ============ State Variables ============

    /// @dev Counter for agent IDs
    uint256 private _agentIdCounter;

    /// @dev Mapping from agent ID to agent info
    mapping(uint256 => AgentInfo) private _agents;

    /// @dev Mapping from domain to agent ID
    mapping(string => uint256) private _domainToAgentId;

    /// @dev Mapping from address to agent ID
    mapping(address => uint256) private _addressToAgentId;

    /// @dev Reference to the ReputationRegistry (optional, can be zero address)
    IReputationRegistry public reputationRegistry;

    /// @dev Reference to the ValidationRegistry (optional, can be zero address)
    IValidationRegistry public validationRegistry;

    // ============ Constructor ============

    /**
     * @dev Constructor initializes the registry and optionally sets registry references
     * @param _reputationRegistry Address of the ReputationRegistry (can be zero address)
     * @param _validationRegistry Address of the ValidationRegistry (can be zero address)
     */
    constructor(address _reputationRegistry, address _validationRegistry) {
        // Start agent IDs from 1 (0 is reserved for "not found")
        _agentIdCounter = 1;

        // Set registry references (can be updated later)
        if (_reputationRegistry != address(0)) {
            reputationRegistry = IReputationRegistry(_reputationRegistry);
        }
        if (_validationRegistry != address(0)) {
            validationRegistry = IValidationRegistry(_validationRegistry);
        }
    }

    // ============ Write Functions ============
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function newAgent(
        string calldata agentDomain, 
        address agentAddress
    ) external payable returns (uint256 agentId) {

        // Validate inputs
        if (bytes(agentDomain).length == 0) {
            revert InvalidDomain();
        }
        if (agentAddress == address(0)) {
            revert InvalidAddress();
        }
        
        // Check for duplicates
        if (_domainToAgentId[agentDomain] != 0) {
            revert DomainAlreadyRegistered();
        }
        if (_addressToAgentId[agentAddress] != 0) {
            revert AddressAlreadyRegistered();
        }

        // Validate registration fee payment
        if (msg.value < REGISTRATION_FEE) {
            revert InsufficientFee();
        }

        // Assign new agent ID
        agentId = _agentIdCounter++;
        
        // Store agent info
        _agents[agentId] = AgentInfo({
            agentId: agentId,
            agentDomain: agentDomain,
            agentAddress: agentAddress
        });
        
        // Create lookup mappings
        _domainToAgentId[agentDomain] = agentId;
        _addressToAgentId[agentAddress] = agentId;
        
        // Burn the registration fee by not forwarding it anywhere
        // The ETH stays locked in this contract forever
        
        emit AgentRegistered(agentId, agentDomain, agentAddress);
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function updateAgent(
        uint256 agentId,
        string calldata newAgentDomain,
        address newAgentAddress
    ) external returns (bool success) {
        // Validate agent exists
        AgentInfo storage agent = _agents[agentId];
        if (agent.agentId == 0) {
            revert AgentNotFound();
        }
        
        // Check authorization
        if (msg.sender != agent.agentAddress) {
            revert UnauthorizedUpdate();
        }
        
        bool domainChanged = bytes(newAgentDomain).length > 0;
        bool addressChanged = newAgentAddress != address(0);
        
        // Validate new values if provided
        if (domainChanged) {
            if (_domainToAgentId[newAgentDomain] != 0) {
                revert DomainAlreadyRegistered();
            }
        }
        
        if (addressChanged) {
            if (_addressToAgentId[newAgentAddress] != 0) {
                revert AddressAlreadyRegistered();
            }
        }
        
        // Update domain if provided
        if (domainChanged) {
            // Remove old domain mapping
            delete _domainToAgentId[agent.agentDomain];
            // Set new domain
            agent.agentDomain = newAgentDomain;
            _domainToAgentId[newAgentDomain] = agentId;
        }
        
        // Update address if provided
        if (addressChanged) {
            // Remove old address mapping
            delete _addressToAgentId[agent.agentAddress];
            // Set new address
            agent.agentAddress = newAgentAddress;
            _addressToAgentId[newAgentAddress] = agentId;
        }
        
        emit AgentUpdated(agentId, agent.agentDomain, agent.agentAddress);
        return true;
    }

    // ============ Read Functions ============
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function getAgent(uint256 agentId) external view returns (AgentInfo memory agentInfo) {
        agentInfo = _agents[agentId];
        if (agentInfo.agentId == 0) {
            revert AgentNotFound();
        }
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function resolveByDomain(string calldata agentDomain) external view returns (AgentInfo memory agentInfo) {
        uint256 agentId = _domainToAgentId[agentDomain];
        if (agentId == 0) {
            revert AgentNotFound();
        }
        agentInfo = _agents[agentId];
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function resolveByAddress(address agentAddress) external view returns (AgentInfo memory agentInfo) {
        uint256 agentId = _addressToAgentId[agentAddress];
        if (agentId == 0) {
            revert AgentNotFound();
        }
        agentInfo = _agents[agentId];
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function getAgentCount() external view returns (uint256 count) {
        return _agentIdCounter - 1; // Subtract 1 because we start from 1
    }
    
    /**
     * @inheritdoc IIdentityRegistry
     */
    function agentExists(uint256 agentId) external view returns (bool exists) {
        return _agents[agentId].agentId != 0;
    }

    // ============ ERC8004 Extended Functions ============

    /**
     * @dev Check if feedback is authorized between a client and server agent
     * @param agentClientId The client agent ID
     * @param agentServerId The server agent ID
     * @return isAuthorized True if feedback is authorized
     * @return feedbackAuthId The unique authorization ID
     * @notice Returns false if ReputationRegistry is not set
     */
    function getAgentReputationAuth(
        uint256 agentClientId,
        uint256 agentServerId
    ) external view returns (bool isAuthorized, bytes32 feedbackAuthId) {
        if (address(reputationRegistry) == address(0)) {
            return (false, bytes32(0));
        }
        return reputationRegistry.isFeedbackAuthorized(agentClientId, agentServerId);
    }

    /**
     * @dev Get validation response for a specific data hash
     * @param dataHash The hash of the validated data
     * @return hasResponse True if a response exists
     * @return response The validation score (0-100)
     * @notice Returns false if ValidationRegistry is not set
     */
    function getAgentValidationResponse(
        bytes32 dataHash
    ) external view returns (bool hasResponse, uint8 response) {
        if (address(validationRegistry) == address(0)) {
            return (false, 0);
        }
        return validationRegistry.getValidationResponse(dataHash);
    }

    /**
     * @dev Check if a validation request exists and is pending for a data hash
     * @param dataHash The hash of the data being validated
     * @return exists True if the request exists
     * @return pending True if the request is still pending response
     * @notice Returns false if ValidationRegistry is not set
     */
    function getAgentValidationStatus(
        bytes32 dataHash
    ) external view returns (bool exists, bool pending) {
        if (address(validationRegistry) == address(0)) {
            return (false, false);
        }
        return validationRegistry.isValidationPending(dataHash);
    }

    /**
     * @dev Get complete validation request details
     * @param dataHash The hash of the data being validated
     * @return request The validation request details
     * @notice Reverts if ValidationRegistry is not set or request not found
     */
    function getAgentValidationRequest(
        bytes32 dataHash
    ) external view returns (IValidationRegistry.Request memory request) {
        require(address(validationRegistry) != address(0), "ValidationRegistry not set");
        return validationRegistry.getValidationRequest(dataHash);
    }

    /**
     * @dev Get comprehensive agent information including identity, reputation, and validation status
     * @param agentId The agent's unique identifier
     * @param otherAgentId Optional: another agent ID to check reputation relationship with
     * @param dataHash Optional: data hash to check validation status for
     * @return agentInfo The agent's identity information
     * @return hasReputationAuth True if reputation is authorized with otherAgentId
     * @return feedbackAuthId The reputation authorization ID (if applicable)
     * @return hasValidation True if validation exists for dataHash
     * @return validationPending True if validation is still pending
     * @return validationScore The validation score (0-100, only valid if hasValidation is true)
     */
    function getAgentFullInfo(
        uint256 agentId,
        uint256 otherAgentId,
        bytes32 dataHash
    )
        external
        view
        returns (
            AgentInfo memory agentInfo,
            bool hasReputationAuth,
            bytes32 feedbackAuthId,
            bool hasValidation,
            bool validationPending,
            uint8 validationScore
        )
    {
        // Get agent info
        agentInfo = _agents[agentId];
        if (agentInfo.agentId == 0) {
            revert AgentNotFound();
        }

        // Get reputation info if registry is set and otherAgentId provided
        if (address(reputationRegistry) != address(0) && otherAgentId != 0) {
            (hasReputationAuth, feedbackAuthId) = reputationRegistry.isFeedbackAuthorized(
                agentId,
                otherAgentId
            );
        }

        // Get validation info if registry is set and dataHash provided
        if (address(validationRegistry) != address(0) && dataHash != bytes32(0)) {
            bool exists;
            (exists, validationPending) = validationRegistry.isValidationPending(dataHash);
            if (exists) {
                (hasValidation, validationScore) = validationRegistry.getValidationResponse(dataHash);
            }
        }
    }

    // ============ Admin Functions ============

    /**
     * @dev Update the ReputationRegistry address
     * @param _reputationRegistry New ReputationRegistry address
     * @notice This function would typically be restricted to contract owner/admin
     * @dev For this implementation, anyone can update (should add access control in production)
     */
    function setReputationRegistry(address _reputationRegistry) external {
        reputationRegistry = IReputationRegistry(_reputationRegistry);
    }

    /**
     * @dev Update the ValidationRegistry address
     * @param _validationRegistry New ValidationRegistry address
     * @notice This function would typically be restricted to contract owner/admin
     * @dev For this implementation, anyone can update (should add access control in production)
     */
    function setValidationRegistry(address _validationRegistry) external {
        validationRegistry = IValidationRegistry(_validationRegistry);
    }

    // ============ Internal Functions ============

    // Note: Registration fee is burned by keeping it locked in this contract
    // This is more gas-efficient than transferring to address(0)
}