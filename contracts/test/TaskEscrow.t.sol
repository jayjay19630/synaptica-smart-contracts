// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {TaskEscrow} from "../src/TaskEscrow.sol";

contract TaskEscrowTest is Test {
    TaskEscrow private escrow;

    address payable private marketplace = payable(address(0xA11CE));
    address private client = address(0xB0B);
    address payable private worker = payable(address(0xC0FFEE));
    address payable private verifierOne = payable(address(0xD00D));
    address payable private verifierTwo = payable(address(0xF00D));

    bytes32 private constant TASK_ID = keccak256("task-1");

    uint16 private constant MARKETPLACE_FEE_BPS = 500; // 5%
    uint16 private constant VERIFIER_FEE_BPS = 200; // 2%
    uint8 private constant APPROVALS_REQUIRED = 2;

    function setUp() public {
        escrow = new TaskEscrow(marketplace);
        vm.deal(client, 50 ether);
    }

    function _verifierList() private view returns (address[] memory) {
        address[] memory verifiers = new address[](2);
        verifiers[0] = verifierOne;
        verifiers[1] = verifierTwo;
        return verifiers;
    }

    function testCreateEscrowStoresState() public {
        uint256 amount = 10 ether;
        address[] memory verifiers = _verifierList();

        vm.prank(client);
        escrow.createEscrow{value: amount}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );

        TaskEscrow.Escrow memory stored = escrow.getEscrow(TASK_ID);
        assertEq(stored.client, client, "client mismatch");
        assertEq(stored.worker, worker, "worker mismatch");
        assertEq(stored.amount, amount, "amount mismatch");
        assertEq(stored.marketplaceFeeBps, MARKETPLACE_FEE_BPS, "marketplace fee");
        assertEq(stored.verifierFeeBps, VERIFIER_FEE_BPS, "verifier fee");
        assertEq(uint8(stored.status), uint8(TaskEscrow.Status.Funded), "status");
        assertEq(stored.approvalsRequired, APPROVALS_REQUIRED, "approvals required");

        address[] memory storedVerifiers = escrow.getVerifiers(TASK_ID);
        assertEq(storedVerifiers.length, verifiers.length, "verifier length");
        assertEq(storedVerifiers[0], verifiers[0], "verifier one");
        assertEq(storedVerifiers[1], verifiers[1], "verifier two");
    }

    function testReleaseDistributesFunds() public {
        uint256 amount = 10 ether;
        address[] memory verifiers = _verifierList();

        vm.prank(client);
        escrow.createEscrow{value: amount}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );

        uint256 denominator = escrow.BPS_DENOMINATOR();
        uint256 expectedMarketplace = (amount * MARKETPLACE_FEE_BPS) / denominator;
        uint256 expectedVerifierTotal = (amount * VERIFIER_FEE_BPS) / denominator;
        uint256 baseVerifierShare = expectedVerifierTotal / verifiers.length;
        uint256 remainder = expectedVerifierTotal - (baseVerifierShare * verifiers.length);
        uint256 expectedVerifierOne = baseVerifierShare + (remainder > 0 ? 1 : 0);
        uint256 expectedVerifierTwo = baseVerifierShare;
        uint256 expectedWorker = amount - expectedMarketplace - expectedVerifierTotal;

        uint256 marketplaceBalanceBefore = marketplace.balance;
        uint256 workerBalanceBefore = worker.balance;
        uint256 verifierOneBalanceBefore = verifierOne.balance;
        uint256 verifierTwoBalanceBefore = verifierTwo.balance;

        vm.prank(verifierOne);
        escrow.approveRelease(TASK_ID);

        vm.prank(verifierTwo);
        escrow.approveRelease(TASK_ID);

        assertEq(worker.balance - workerBalanceBefore, expectedWorker, "worker payout");
        assertEq(marketplace.balance - marketplaceBalanceBefore, expectedMarketplace, "marketplace fee");
        assertEq(verifierOne.balance - verifierOneBalanceBefore, expectedVerifierOne, "verifier one fee");
        assertEq(verifierTwo.balance - verifierTwoBalanceBefore, expectedVerifierTwo, "verifier two fee");

        TaskEscrow.Escrow memory stored = escrow.getEscrow(TASK_ID);
        assertEq(uint8(stored.status), uint8(TaskEscrow.Status.Released), "status should be released");
        assertEq(stored.amount, 0, "amount should be zero after release");
        assertEq(stored.releaseApprovalCount, APPROVALS_REQUIRED, "approval count");
    }

    function testRefundPaysClientAndVerifiers() public {
        uint256 amount = 5 ether;
        address[] memory verifiers = _verifierList();

        vm.prank(client);
        escrow.createEscrow{value: amount}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );

        uint256 verifierTotal = (amount * VERIFIER_FEE_BPS) / escrow.BPS_DENOMINATOR();
        uint256 expectedRefund = amount - verifierTotal;
        uint256 baseVerifierShare = verifierTotal / verifiers.length;
        uint256 remainder = verifierTotal - (baseVerifierShare * verifiers.length);
        uint256 expectedVerifierOne = baseVerifierShare + (remainder > 0 ? 1 : 0);
        uint256 expectedVerifierTwo = baseVerifierShare;

        uint256 clientBalanceBefore = client.balance;
        uint256 verifierOneBalanceBefore = verifierOne.balance;
        uint256 verifierTwoBalanceBefore = verifierTwo.balance;

        vm.prank(verifierOne);
        escrow.approveRefund(TASK_ID);

        vm.prank(verifierTwo);
        escrow.approveRefund(TASK_ID);

        assertEq(client.balance - clientBalanceBefore, expectedRefund, "client refund amount");
        assertEq(verifierOne.balance - verifierOneBalanceBefore, expectedVerifierOne, "verifier one fee");
        assertEq(verifierTwo.balance - verifierTwoBalanceBefore, expectedVerifierTwo, "verifier two fee");

        TaskEscrow.Escrow memory stored = escrow.getEscrow(TASK_ID);
        assertEq(uint8(stored.status), uint8(TaskEscrow.Status.Refunded), "status should be refunded");
        assertEq(stored.amount, 0, "amount should be zero after refund");
        assertEq(stored.refundApprovalCount, APPROVALS_REQUIRED, "refund approvals");
    }

    function testOnlyVerifiersCanApprove() public {
        address[] memory verifiers = _verifierList();

        vm.prank(client);
        escrow.createEscrow{value: 1 ether}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );

        vm.expectRevert(TaskEscrow.Unauthorized.selector);
        escrow.approveRelease(TASK_ID);

        vm.expectRevert(TaskEscrow.Unauthorized.selector);
        escrow.approveRefund(TASK_ID);
    }

    function testCannotCreateDuplicateEscrow() public {
        address[] memory verifiers = _verifierList();

        vm.prank(client);
        escrow.createEscrow{value: 1 ether}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );

        vm.expectRevert(TaskEscrow.EscrowAlreadyExists.selector);
        vm.prank(client);
        escrow.createEscrow{value: 1 ether}(
            TASK_ID,
            worker,
            verifiers,
            APPROVALS_REQUIRED,
            MARKETPLACE_FEE_BPS,
            VERIFIER_FEE_BPS
        );
    }
}
