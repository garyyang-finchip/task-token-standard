// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TaskToken} from "../contracts/TaskToken.sol";
import {ITaskTender} from "../contracts/interfaces/ITaskTender.sol";
import {ITaskAdmission} from "../contracts/interfaces/ITaskAdmission.sol";
import {HashlockVerifier} from "../contracts/verifiers/HashlockVerifier.sol";

/// @dev Unrestricted test controls. The deliberately non-view ABI also attempts writes
/// to prove that the kernel uses STATICCALL rather than trusting the policy's declaration.
contract AdmissionProbe {
    uint256 public mode;
    uint256 public writes;
    bytes32 public expected;
    function configure(uint256 mode_, bytes32 expected_) external { mode = mode_; expected = expected_; }
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(ITaskAdmission).interfaceId;
    }
    function admit(address task, uint256 token, address submitter, bytes32 result, uint64 version)
        external returns (bool)
    {
        if (mode == 1) return false;
        if (mode == 2) revert("policy unavailable");
        if (mode == 3) { assembly { return(0, 0) } }
        if (mode == 4) { assembly { mstore(0, 2) return(0, 32) } }
        if (mode == 5) { assembly { mstore(0, 1) return(0, 4096) } }
        if (mode == 6) writes++;
        if (mode == 7) { assembly { for {} 1 {} {} } }
        return expected == bytes32(0)
            || expected == keccak256(abi.encode(msg.sender, task, token, submitter, result, version));
    }
}

contract InvalidAdmissionDeclaration {
    fallback() external { assembly { mstore(0, 2) return(0, 32) } }
}

/// @author Ted (@haot3x)
contract AdmissionSlotTest is Test {
    TaskToken private task;
    AdmissionProbe private policy;
    HashlockVerifier private verifier;
    uint256 private id;
    address private constant PUBLISHER = address(0xB0B);
    address private constant WORKER = address(0xCAFE);
    address private constant JUDGE = address(0xD00D);
    bytes32 private constant DOC = 0x139d544b821b13ebea14f1b0fe18577222e415c2966e3a3511c4196055232202;
    bytes32 private constant ROOT = 0x4813494d137e1631bba301d5acab6e7bb7aa74ce1185d456565ef51d737677b2;
    bytes32 private constant RESULT = keccak256("delivered bytes");

    function setUp() public {
        vm.warp(1000);
        task = new TaskToken("Admission prototype", "TASK");
        policy = new AdmissionProbe();
        verifier = new HashlockVerifier();
        id = _mint(address(policy), JUDGE);
        vm.deal(address(this), 10 ether);
        task.fundTask{value: 2 ether}(id, 2 ether);
    }

    function _terms() private pure returns (ITaskTender.TenderTerms memory) {
        return ITaskTender.TenderTerms(address(0), 1 ether, 2, 10_000, 20_000, 1000, 1, 100);
    }

    function _mint(address admission, address judge) private returns (uint256) {
        return task.mintTask(PUBLISHER, PUBLISHER, judge, DOC, ROOT, "local:task",
            _terms(), admission);
    }

    function _submit() private returns (uint256) {
        vm.prank(WORKER);
        return task.submitFulfillment(id, RESULT, "local:result");
    }

    function _refused() private {
        uint256 beforeCount = task.submissionCountOf(id);
        uint64 beforePending = task.pendingOf(id);
        uint256 beforeLocked = task.lockedEscrowOf(id);
        vm.recordLogs();
        vm.prank(WORKER);
        vm.expectRevert(bytes("TaskToken: not admitted"));
        task.submitFulfillment(id, RESULT, "local:result");
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(task.submissionCountOf(id), beforeCount);
        assertEq(task.pendingOf(id), beforePending);
        assertEq(task.lockedEscrowOf(id), beforeLocked);
        assertEq(task.escrowBalanceOf(id), 2 ether);
        assertEq(task.completionsInEpochOf(id, 1), 0);
    }

    function test_zeroSlotPreservesOriginalMintAndJudgmentDeadline() public {
        uint256 open = task.mintTask(PUBLISHER, PUBLISHER, JUDGE, DOC, ROOT,
            "local:task", _terms());
        assertEq(task.admissionAuthorityOf(open), address(0));
        task.fundTask{value: 1 ether}(open, 1 ether);
        vm.prank(WORKER);
        uint256 delivery = task.submitFulfillment(open, RESULT, "local:result");
        vm.warp(1101);
        task.claimUnjudged(open, delivery);
        assertEq(WORKER.balance, 1 ether);
    }

    function test_policyReceivesExactTaskCallerSubmitterResultAndVersion() public {
        policy.configure(0, keccak256(abi.encode(address(task), address(task), id, WORKER, RESULT, uint64(1))));
        uint256 delivery = _submit();
        assertEq(task.submissionOf(id, delivery).fulfiller, WORKER);
        assertEq(task.submissionOf(id, delivery).taskVersion, 1);
        assertEq(task.pendingOf(id), 1);
    }

    function test_falseAdmissionCannotReserveOrSpendPacingBudget() public {
        policy.configure(1, 0);
        _refused();
        policy.configure(0, 0);
        uint256 delivery = _submit();
        vm.prank(JUDGE);
        task.acceptFulfillment(id, delivery);
        assertEq(task.completionsInEpochOf(id, 1), 1);
        assertEq(WORKER.balance, 1 ether);
    }

    function test_revertingPolicyFailsClosed() public { policy.configure(2, 0); _refused(); }
    function test_emptyReturnFailsClosed() public { policy.configure(3, 0); _refused(); }
    function test_nonBooleanReturnFailsClosed() public { policy.configure(4, 0); _refused(); }
    function test_oversizedReturnFailsClosed() public { policy.configure(5, 0); _refused(); }

    function test_policyCannotWriteDuringAdmission() public {
        policy.configure(6, 0);
        _refused();
        assertEq(policy.writes(), 0);
    }

    function test_gasExhaustingPolicyReturnsControlledRefusal() public {
        policy.configure(7, 0);
        vm.prank(WORKER);
        (bool ok, bytes memory data) = address(task).call{gas: 500_000}(
            abi.encodeCall(task.submitFulfillment, (id, RESULT, "local:result")));
        assertFalse(ok);
        assertEq(data, abi.encodeWithSignature("Error(string)", "TaskToken: not admitted"));
        assertEq(task.pendingOf(id), 0);
    }

    function test_badMintDeclarationCannotCreateToken() public {
        uint256 next = task.nextId();
        vm.expectRevert(bytes("TaskToken: invalid admission authority"));
        _mint(WORKER, JUDGE);
        address invalid = address(new InvalidAdmissionDeclaration());
        vm.expectRevert(bytes("TaskToken: invalid admission authority"));
        _mint(invalid, JUDGE);
        assertEq(task.nextId(), next);
    }

    function test_machineProofFailureStillReleasesExpiredReservation() public {
        id = _mint(address(policy), address(verifier));
        task.fundTask{value: 2 ether}(id, 2 ether);
        uint256 delivery = _submit();
        vm.expectRevert(bytes("TaskToken: verification failed"));
        task.settleFulfillment(id, delivery, "wrong answer");
        policy.configure(1, 0); // Later admission refusal cannot block cleanup of admitted work.
        vm.warp(1101);
        task.releaseExpired(id, delivery);
        assertEq(task.pendingOf(id), 0);
        assertEq(task.lockedEscrowOf(id), 0);
        assertEq(task.escrowBalanceOf(id), 2 ether);
    }

    function test_authoritySlotAndInterfaceAreExplicit() public {
        assertTrue(task.supportsInterface(type(ITaskTender).interfaceId));
        bytes4 oldId = type(ITaskTender).interfaceId ^ ITaskTender.admissionAuthorityOf.selector;
        assertFalse(task.supportsInterface(oldId));
        assertEq(type(ITaskAdmission).interfaceId, ITaskAdmission.admit.selector);
        vm.prank(JUDGE);
        task.setAcceptanceAuthority(id, WORKER);
        vm.prank(PUBLISHER);
        task.setUpdateAuthority(id, WORKER);
        vm.prank(PUBLISHER);
        task.transferFrom(PUBLISHER, WORKER, id);
        assertEq(task.admissionAuthorityOf(id), address(policy));
        uint256 next = task.nextId();
        vm.expectEmit(true, true, false, true, address(task));
        emit ITaskTender.AdmissionAuthoritySet(next, address(0));
        _mint(address(0), JUDGE);
    }
}
