// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TaskEscrow - Hedera marketplace escrow with multi-verifier consensus
/// @notice Holds HBAR deposits for marketplace tasks and releases funds once enough verifiers approve
contract TaskEscrow {
    /// @dev Escrow lifecycle states
    enum Status {
        None,
        Funded,
        Released,
        Refunded
    }

    /// @dev Escrow details stored per task
    struct Escrow {
        address client;
        address worker;
        uint256 amount;
        uint16 marketplaceFeeBps;
        uint16 verifierFeeBps;
        Status status;
        uint8 approvalsRequired;
        uint8 releaseApprovalCount;
        uint8 refundApprovalCount;
    }

    /// @dev Total basis points denominator (100%)
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @dev Marketplace fee recipient wallet
    address payable public immutable marketplaceTreasury;

    /// @dev Reentrancy guard storage (1 = not entered, 2 = entered)
    uint256 private _status;

    /// @dev Map task IDs to their escrow records
    mapping(bytes32 => Escrow) private escrows;

    /// @dev Track verifier set per task
    mapping(bytes32 => address[]) private escrowVerifiers;
    mapping(bytes32 => mapping(address => bool)) private isVerifierForTask;

    /// @dev Track approvals per task
    mapping(bytes32 => mapping(address => bool)) private releaseApprovals;
    mapping(bytes32 => mapping(address => bool)) private refundApprovals;

    /// @dev Emitted when a new escrow is funded
    event EscrowCreated(
        bytes32 indexed taskId,
        address indexed client,
        address indexed worker,
        uint256 amount,
        uint16 marketplaceFeeBps,
        uint16 verifierFeeBps,
        uint8 approvalsRequired,
        uint8 verifierCount
    );

    /// @dev Emitted when a verifier submits a release approval
    event ReleaseApprovalSubmitted(
        bytes32 indexed taskId,
        address indexed verifier,
        uint8 approvals,
        uint8 approvalsRequired
    );

    /// @dev Emitted when a verifier submits a refund approval
    event RefundApprovalSubmitted(
        bytes32 indexed taskId,
        address indexed verifier,
        uint8 approvals,
        uint8 approvalsRequired
    );

    /// @dev Emitted when funds are released to the worker
    event EscrowReleased(
        bytes32 indexed taskId,
        address indexed worker,
        uint256 workerAmount,
        uint256 marketplaceFee,
        uint256 verifierFee,
        uint8 approvalsUsed
    );

    /// @dev Emitted when funds are refunded to the client
    event EscrowRefunded(
        bytes32 indexed taskId,
        address indexed client,
        uint256 refundedAmount,
        uint256 verifierFee,
        uint8 approvalsUsed
    );

    /// @dev Error: zero address provided where not allowed
    error ZeroAddress();
    /// @dev Error: escrow already exists for the given task ID
    error EscrowAlreadyExists();
    /// @dev Error: supplied HBAR amount is zero
    error InvalidAmount();
    /// @dev Error: combined fee basis points exceed 100%
    error InvalidFeeConfiguration();
    /// @dev Error: invalid verifier configuration
    error InvalidVerifierConfiguration();
    /// @dev Error: verifier specified more than once
    error DuplicateVerifier(address verifier);
    /// @dev Error: caller is not authorized for the action
    error Unauthorized();
    /// @dev Error: verifier already approved this path
    error AlreadyApproved();
    /// @dev Error: escrow is not funded or in wrong status for the action
    error InvalidEscrowState();
    /// @dev Error: reentrancy guard hit
    error ReentrancyGuardActive();
    /// @dev Error: transfer call failed
    error TransferFailed(address recipient);

    /// @param treasury Address that receives marketplace fees
    constructor(address payable treasury) {
        if (treasury == address(0)) revert ZeroAddress();
        marketplaceTreasury = treasury;
        _status = 1;
    }

    /// @notice Returns the escrow details for a task ID
    function getEscrow(bytes32 taskId) external view returns (Escrow memory) {
        return escrows[taskId];
    }

    /// @notice Returns the verifier list for a task
    function getVerifiers(bytes32 taskId) external view returns (address[] memory) {
        return escrowVerifiers[taskId];
    }

    /// @notice Fund an escrow for a task; caller becomes the client
    /// @param taskId Unique identifier for the task
    /// @param worker Wallet that should receive payment after verification
    /// @param verifiers List of wallets allowed to approve release/refund
    /// @param approvalsRequired Number of approvals required to finalize
    /// @param marketplaceFeeBps Marketplace fee percentage in basis points
    /// @param verifierFeeBps Verifier fee percentage in basis points
    function createEscrow(
        bytes32 taskId,
        address worker,
        address[] calldata verifiers,
        uint8 approvalsRequired,
        uint16 marketplaceFeeBps,
        uint16 verifierFeeBps
    ) external payable {
        if (worker == address(0)) revert ZeroAddress();
        if (msg.value == 0) revert InvalidAmount();
        if (escrows[taskId].status != Status.None) revert EscrowAlreadyExists();

        uint32 totalFeeBps = uint32(marketplaceFeeBps) + uint32(verifierFeeBps);
        if (totalFeeBps > BPS_DENOMINATOR) revert InvalidFeeConfiguration();

        uint256 verifierCount = verifiers.length;
        if (verifierCount == 0 || approvalsRequired == 0 || approvalsRequired > verifierCount) {
            revert InvalidVerifierConfiguration();
        }
        if (verifierCount > type(uint8).max) {
            revert InvalidVerifierConfiguration();
        }

        Escrow storage escrowRecord = escrows[taskId];
        escrowRecord.client = msg.sender;
        escrowRecord.worker = worker;
        escrowRecord.amount = msg.value;
        escrowRecord.marketplaceFeeBps = marketplaceFeeBps;
        escrowRecord.verifierFeeBps = verifierFeeBps;
        escrowRecord.status = Status.Funded;
        escrowRecord.approvalsRequired = approvalsRequired;

        address[] storage storedVerifiers = escrowVerifiers[taskId];
        for (uint256 i = 0; i < verifierCount; ++i) {
            address verifier = verifiers[i];
            if (verifier == address(0)) revert ZeroAddress();
            if (isVerifierForTask[taskId][verifier]) {
                revert DuplicateVerifier(verifier);
            }
            isVerifierForTask[taskId][verifier] = true;
            storedVerifiers.push(verifier);
        }

        emit EscrowCreated(
            taskId,
            msg.sender,
            worker,
            msg.value,
            marketplaceFeeBps,
            verifierFeeBps,
            approvalsRequired,
            uint8(verifierCount)
        );
    }

    /// @notice Approve fund release after task verification
    /// @param taskId Task identifier of the funded escrow
    function approveRelease(bytes32 taskId) external nonReentrant {
        Escrow storage escrowRecord = escrows[taskId];
        if (escrowRecord.status != Status.Funded) revert InvalidEscrowState();
        if (!isVerifierForTask[taskId][msg.sender]) revert Unauthorized();
        if (releaseApprovals[taskId][msg.sender]) revert AlreadyApproved();

        releaseApprovals[taskId][msg.sender] = true;
        escrowRecord.releaseApprovalCount += 1;

        emit ReleaseApprovalSubmitted(
            taskId,
            msg.sender,
            escrowRecord.releaseApprovalCount,
            escrowRecord.approvalsRequired
        );

        if (escrowRecord.releaseApprovalCount >= escrowRecord.approvalsRequired) {
            _executeRelease(taskId, escrowRecord);
        }
    }

    /// @notice Approve refund after failed verification
    /// @param taskId Task identifier of the funded escrow
    function approveRefund(bytes32 taskId) external nonReentrant {
        Escrow storage escrowRecord = escrows[taskId];
        if (escrowRecord.status != Status.Funded) revert InvalidEscrowState();
        if (!isVerifierForTask[taskId][msg.sender]) revert Unauthorized();
        if (refundApprovals[taskId][msg.sender]) revert AlreadyApproved();

        refundApprovals[taskId][msg.sender] = true;
        escrowRecord.refundApprovalCount += 1;

        emit RefundApprovalSubmitted(
            taskId,
            msg.sender,
            escrowRecord.refundApprovalCount,
            escrowRecord.approvalsRequired
        );

        if (escrowRecord.refundApprovalCount >= escrowRecord.approvalsRequired) {
            _executeRefund(taskId, escrowRecord);
        }
    }

    /// @dev Execute release distribution
    function _executeRelease(bytes32 taskId, Escrow storage escrowRecord) private {
        uint256 amount = escrowRecord.amount;
        uint256 marketplaceFee = (amount * escrowRecord.marketplaceFeeBps) / BPS_DENOMINATOR;
        uint256 verifierFee = (amount * escrowRecord.verifierFeeBps) / BPS_DENOMINATOR;
        uint256 workerAmount = amount - marketplaceFee - verifierFee;

        escrowRecord.status = Status.Released;
        escrowRecord.amount = 0;

        if (workerAmount > 0) {
            _sendValue(payable(escrowRecord.worker), workerAmount);
        }

        if (marketplaceFee > 0) {
            _sendValue(marketplaceTreasury, marketplaceFee);
        }

        uint256 verifierPaid = _distributeVerifierFee(taskId, verifierFee, true);

        emit EscrowReleased(
            taskId,
            escrowRecord.worker,
            workerAmount,
            marketplaceFee,
            verifierPaid,
            escrowRecord.releaseApprovalCount
        );

        _clearVerifierState(taskId);
    }

    /// @dev Execute refund distribution
    function _executeRefund(bytes32 taskId, Escrow storage escrowRecord) private {
        uint256 amount = escrowRecord.amount;
        uint256 verifierFee = (amount * escrowRecord.verifierFeeBps) / BPS_DENOMINATOR;
        uint256 refundAmount = amount - verifierFee;

        escrowRecord.status = Status.Refunded;
        escrowRecord.amount = 0;

        if (refundAmount > 0) {
            _sendValue(payable(escrowRecord.client), refundAmount);
        }

        uint256 verifierPaid = _distributeVerifierFee(taskId, verifierFee, false);

        emit EscrowRefunded(
            taskId,
            escrowRecord.client,
            refundAmount,
            verifierPaid,
            escrowRecord.refundApprovalCount
        );

        _clearVerifierState(taskId);
    }

    /// @dev Distribute verifier fees among approving verifiers
    function _distributeVerifierFee(
        bytes32 taskId,
        uint256 totalFee,
        bool isRelease
    ) private returns (uint256 paidTotal) {
        if (totalFee == 0) {
            return 0;
        }

        address[] storage verifiers = escrowVerifiers[taskId];
        uint256 approvals;
        uint256 length = verifiers.length;

        for (uint256 i = 0; i < length; ++i) {
            address verifier = verifiers[i];
            bool approved = isRelease
                ? releaseApprovals[taskId][verifier]
                : refundApprovals[taskId][verifier];
            if (approved) {
                approvals += 1;
            }
        }

        if (approvals == 0) {
            _sendValue(marketplaceTreasury, totalFee);
            return totalFee;
        }

        uint256 baseShare = totalFee / approvals;
        uint256 remainder = totalFee - (baseShare * approvals);

        for (uint256 i = 0; i < length; ++i) {
            address verifier = verifiers[i];
            bool approved = isRelease
                ? releaseApprovals[taskId][verifier]
                : refundApprovals[taskId][verifier];
            if (!approved) continue;

            uint256 share = baseShare;
            if (remainder > 0) {
                share += 1;
                remainder -= 1;
            }

            _sendValue(payable(verifier), share);
            paidTotal += share;
        }

        return paidTotal;
    }

    /// @dev Clear verifier state after escrow concludes to free storage
    function _clearVerifierState(bytes32 taskId) private {
        address[] storage verifiers = escrowVerifiers[taskId];
        uint256 length = verifiers.length;
        for (uint256 i = 0; i < length; ++i) {
            address verifier = verifiers[i];
            isVerifierForTask[taskId][verifier] = false;
            releaseApprovals[taskId][verifier] = false;
            refundApprovals[taskId][verifier] = false;
        }
        delete escrowVerifiers[taskId];
    }

    /// @dev Internal helper to send value to a recipient
    function _sendValue(address payable recipient, uint256 amount) private {
        if (amount == 0) return;
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert TransferFailed(recipient);
    }

    /// @dev Simple reentrancy guard modifier
    modifier nonReentrant() {
        if (_status == 2) revert ReentrancyGuardActive();
        _status = 2;
        _;
        _status = 1;
    }
}
