// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TaskToken} from "../contracts/TaskToken.sol";
import {ITaskToken} from "../contracts/interfaces/ITaskToken.sol";
import {ITaskTender} from "../contracts/interfaces/ITaskTender.sol";
import {ITaskVerifier} from "../contracts/interfaces/ITaskVerifier.sol";
import {HashlockVerifier} from "../contracts/verifiers/HashlockVerifier.sol";

/// @dev Test-only award gate: fixes one winner to isolate version-locking from bidding.
/// Not the sealed-bid companion, a submission-time admission slot, or a production adapter.
contract VersionLockedAwardFixture is ITaskVerifier {
    TaskToken private immutable task;
    HashlockVerifier private immutable inner;
    mapping(uint256 => ITaskToken.TaskBinding) public anchorOf;
    mapping(uint256 => address) private winnerOf;

    constructor(TaskToken task_, HashlockVerifier inner_) {
        task = task_;
        inner = inner_;
    }

    // Models the binding read at tender opening; the winner is fixed by the fixture.
    function lock(uint256 tokenId, address winner) external {
        require(msg.sender == task.updateAuthorityOf(tokenId), "fixture: not publisher");
        require(anchorOf[tokenId].version == 0 && winner != address(0), "fixture: invalid lock");
        anchorOf[tokenId] = task.taskOf(tokenId);
        winnerOf[tokenId] = winner;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(ITaskVerifier).interfaceId;
    }

    function verifyFulfillment(
        address taskContract,
        uint256 tokenId,
        uint256 submissionId,
        address fulfiller,
        bytes32 resultHash,
        bytes calldata proof
    ) external view returns (bool) {
        if (msg.sender != address(task) || taskContract != address(task)) return false;
        if (fulfiller != winnerOf[tokenId]) return false;
        // The current binding is deliberately not consulted at settlement time.
        if (task.submissionOf(tokenId, submissionId).taskVersion != anchorOf[tokenId].version) return false;
        return inner.verifyFulfillment(taskContract, tokenId, submissionId, fulfiller, resultHash, proof);
    }
}

/// @notice Regressions for t/29597#31/#33 and ROADMAP candidate 3. Uses the real
/// TaskToken, vault and HashlockVerifier; only the award selection is a fixture.
contract VersionLockedSettlementTest is Test {
    TaskToken private task;
    HashlockVerifier private inner;
    VersionLockedAwardFixture private gate;
    uint256 private tokenId;
    address private constant PUBLISHER = address(0xB0B);
    address private constant WINNER = address(0xCAFE);
    address private constant LOSER = address(0xBEEF);
    address private constant RELAYER = address(0xBAD);
    bytes32 private constant DOCUMENT = sha256("same document across companion-only updates");
    bytes32 private constant ROOT_V1 = sha256("TaskRoot v1");
    bytes32 private constant ROOT_V2 = sha256("TaskRoot v2: different acceptance or eligibility profile");
    uint256 private constant REWARD = 1 ether;

    function setUp() public {
        task = new TaskToken("Version lock regression", "TASK");
        inner = new HashlockVerifier();
        gate = new VersionLockedAwardFixture(task, inner);
        tokenId = task.mintTask(
            PUBLISHER,
            PUBLISHER,
            address(gate),
            DOCUMENT,
            ROOT_V1,
            "ipfs://v1",
            ITaskTender.TenderTerms(address(0), REWARD, 3, 0, 0, 0, 0, 7 days)
        );
        vm.startPrank(PUBLISHER);
        gate.lock(tokenId, WINNER);
        inner.commitAnswer(address(task), tokenId, sha256(bytes("answer")));
        vm.stopPrank();
        vm.deal(address(this), 3 * REWARD);
        task.fundTask{value: 3 * REWARD}(tokenId, 3 * REWARD);
    }

    function submit(address who) private returns (uint256) {
        bytes32 resultHash = sha256(abi.encodePacked(bytes("answer"), who));
        vm.prank(who);
        uint256 submissionId = task.submitFulfillment(tokenId, resultHash, "ipfs://result");
        assertEq(task.submissionOf(tokenId, submissionId).fulfiller, who);
        return submissionId;
    }

    function update(bytes32 root) private {
        vm.startPrank(PUBLISHER);
        task.updateTask(tokenId, DOCUMENT, root);
        vm.stopPrank();
    }

    function settle(uint256 submissionId, bytes memory proof) private {
        vm.prank(RELAYER);
        task.settleFulfillment(tokenId, submissionId, proof);
    }

    function assertVerificationFailsUnchanged(uint256 submissionId, bytes memory proof) private {
        bytes32 beforeSubmission = keccak256(abi.encode(task.submissionOf(tokenId, submissionId)));
        uint256 escrow = task.escrowBalanceOf(tokenId);
        uint256 winnerBalance = WINNER.balance;
        uint64 pending = task.pendingOf(tokenId);
        uint64 completions = task.completionsOf(tokenId);
        vm.expectRevert(bytes("TaskToken: verification failed"));
        settle(submissionId, proof);
        assertEq(keccak256(abi.encode(task.submissionOf(tokenId, submissionId))), beforeSubmission);
        assertEq(task.escrowBalanceOf(tokenId), escrow);
        assertEq(task.lockedEscrowOf(tokenId), uint256(pending) * REWARD);
        assertEq(WINNER.balance, winnerBalance);
        assertEq(task.pendingOf(tokenId), pending);
        assertEq(task.completionsOf(tokenId), completions);
    }

    function test_v1DeliverySettlesAfterV2Update() public {
        uint256 delivery = submit(WINNER);
        update(ROOT_V2);
        assertEq(task.taskOf(tokenId).version, 2);
        assertEq(task.taskOf(tokenId).tdHash, DOCUMENT);
        assertEq(task.submissionOf(tokenId, delivery).taskVersion, 1);
        (bytes32 document, bytes32 root, uint64 version) = gate.anchorOf(tokenId);
        assertEq(document, DOCUMENT);
        assertEq(root, ROOT_V1);
        assertEq(version, 1);
        vm.expectEmit(true, true, true, true, address(task));
        emit ITaskTender.FulfillmentAccepted(tokenId, delivery, WINNER, REWARD);
        settle(delivery, "answer");
        assertEq(uint8(task.submissionOf(tokenId, delivery).status), uint8(ITaskTender.SubmissionStatus.Accepted));
        assertEq(WINNER.balance, REWARD);
        assertEq(task.escrowBalanceOf(tokenId), 2 * REWARD);
        assertEq(task.pendingOf(tokenId), 0);
        assertEq(task.completionsOf(tokenId), 1);
        assertEq(task.taskOf(tokenId).taskHash, ROOT_V2);
        assertFalse(task.isTaskFrozen(tokenId));
        vm.expectRevert(bytes("TaskToken: not pending"));
        settle(delivery, "answer");
        assertEq(WINNER.balance, REWARD);
    }

    function test_deliveryAfterUpdateCannotUseV1Award() public {
        update(ROOT_V2);
        uint256 delivery = submit(WINNER);
        assertEq(task.submissionOf(tokenId, delivery).taskVersion, 2);
        assertVerificationFailsUnchanged(delivery, "answer");
        assertEq(uint8(task.submissionOf(tokenId, delivery).status), uint8(ITaskTender.SubmissionStatus.Pending));
    }

    function test_settlingV1DoesNotMakeV2Payable() public {
        uint256 oldDelivery = submit(WINNER);
        update(ROOT_V2);
        uint256 newDelivery = submit(WINNER);
        settle(oldDelivery, "answer");
        assertVerificationFailsUnchanged(newDelivery, "answer");
        assertEq(WINNER.balance, REWARD);
        assertEq(task.pendingOf(tokenId), 1);
        assertEq(task.lockedEscrowOf(tokenId), REWARD);
        assertEq(task.completionsOf(tokenId), 1);
    }

    function test_reusingOldRootDoesNotRestoreOldVersionAward() public {
        uint256 oldDelivery = submit(WINNER);
        update(ROOT_V2);
        update(ROOT_V1); // Identical root bytes, but the append-only version is now 3.
        uint256 newDelivery = submit(WINNER);
        assertEq(task.taskOf(tokenId).version, 3);
        assertEq(task.taskOf(tokenId).taskHash, ROOT_V1);
        assertVerificationFailsUnchanged(newDelivery, "answer");
        settle(oldDelivery, "answer");
        assertEq(WINNER.balance, REWARD);
        assertEq(task.submissionOf(tokenId, oldDelivery).taskVersion, 1);
    }

    function test_historicalVersionDoesNotBypassWinnerCheck() public {
        uint256 delivery = submit(LOSER);
        update(ROOT_V2);
        assertVerificationFailsUnchanged(delivery, "answer");
        assertEq(LOSER.balance, 0);
    }

    function test_historicalVersionStillRequiresInnerProof() public {
        uint256 delivery = submit(WINNER);
        update(ROOT_V2);
        assertVerificationFailsUnchanged(delivery, "wrong answer");
        settle(delivery, "answer");
        assertEq(WINNER.balance, REWARD);
    }
}
