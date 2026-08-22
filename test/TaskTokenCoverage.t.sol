// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TaskToken} from "../contracts/TaskToken.sol";
import {ITaskToken} from "../contracts/interfaces/ITaskToken.sol";
import {ITaskTender} from "../contracts/interfaces/ITaskTender.sol";
import {IOnchainTaskDocument} from "../contracts/interfaces/IOnchainTaskDocument.sol";
import {HashlockVerifier} from "../contracts/verifiers/HashlockVerifier.sol";

/// A contract fulfiller that reads contract state DURING the payout callback.
/// If checks-effects-interactions holds, the completion count is already
/// incremented and the vault is already debited when the ether lands here.
contract ObservingFulfiller {
    TaskToken public t;
    uint256 public tokenId;
    uint256 public seenCompletions;
    uint256 public seenEscrow;
    uint256 public gasOnReceive;
    bool public received;

    constructor(TaskToken _t) { t = _t; }

    function submit(uint256 id, bytes32 rh) external returns (uint256) {
        tokenId = id;
        return t.submitFulfillment(id, rh, "");
    }

    receive() external payable {
        received = true;
        gasOnReceive = gasleft();
        seenCompletions = t.completionsOf(tokenId);
        seenEscrow = t.escrowBalanceOf(tokenId);
    }
}

/// A deflationary ("fee-on-transfer") ERC-20: the recipient receives less than
/// `amount`, so vault credit MUST be measured by the balance difference.
contract FeeERC20 {
    uint256 public constant FEE_BPS = 100; // 1%
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address sp, uint256 amount) external returns (bool) {
        allowance[msg.sender][sp] = amount; return true;
    }
    function _move(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount - (amount * FEE_BPS) / 10000; // the fee evaporates
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount); return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount; _move(from, to, amount); return true;
    }
}

/// A plain, well-behaved ERC-20 for the refund-path checks.
contract MinimalERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function approve(address sp, uint256 amount) external returns (bool) {
        allowance[msg.sender][sp] = amount; return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount; balanceOf[to] += amount; return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount; balanceOf[to] += amount; return true;
    }
}

/// Second assertion layer: the normative clauses that TaskToken.t.sol leaves
/// unasserted — every `MUST emit`, the post-cancellation and post-freeze
/// closures, the authority gates reachable only through operator approval,
/// rejection terminality across BOTH settlement paths, the expiry refund route,
/// unbounded tenders, native funding arithmetic, per-token submission ids, and
/// checks-effects-interactions on payout.
contract TaskTokenCoverageTest is Test {
    TaskToken t;
    HashlockVerifier hashlock;

    address owner     = address(0xA11CE);
    address publisher = address(0xB0B);
    address judge     = address(0x1CDE);
    address funder    = address(0xF00D);
    address funder2   = address(0xFEED);
    address worker    = address(0xCAFE);
    address worker2   = address(0xBEEF);
    address rando     = address(0xBAD);

    bytes32 TD  = sha256("TASK.md v1");
    bytes32 TH  = sha256("taskroot v1");
    bytes32 TH2 = sha256("taskroot v2");
    bytes32 RES = sha256("deliverable");

    function terms() internal pure returns (ITaskTender.TenderTerms memory) {
        return ITaskTender.TenderTerms(address(0), 1 ether, 2, 0, 0, 0, 0, 7 days);
    }

    function setUp() public {
        t = new TaskToken("Task Token", "TASK");
        hashlock = new HashlockVerifier();
        vm.deal(funder, 100 ether);
        vm.deal(funder2, 100 ether);
        vm.deal(rando, 100 ether);
        vm.deal(worker2, 100 ether);
    }

    function mintDefault() internal returns (uint256) {
        return t.mintTask(owner, publisher, judge, TD, TH, "ipfs://task-v1", terms());
    }

    // ---------------- every MUST-emit clause in the specification
    function test_genesis_events() public {
        uint256 next = t.nextId();
        vm.expectEmit(true, true, true, true);
        emit ITaskToken.TaskUpdated(next, TD, TH, 1);
        vm.expectEmit(true, true, true, true);
        emit ITaskToken.TaskUpdateAuthorityChanged(next, address(0), publisher);
        vm.expectEmit(true, true, true, true);
        emit ITaskTender.AcceptanceAuthorityChanged(next, address(0), judge);
        uint256 id = mintDefault();
        assertEq(id, next);
    }

    function test_lifecycle_events() public {
        uint256 id = mintDefault();

        vm.expectEmit(true, true, true, true);
        emit ITaskToken.TaskURIUpdated(id, "ar://mirror");
        vm.prank(publisher);
        t.setTaskURI(id, "ar://mirror");

        vm.expectEmit(true, true, true, true);
        emit ITaskToken.TaskUpdated(id, TD, TH2, 2);
        vm.prank(publisher);
        t.updateTask(id, TD, TH2);

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.TenderFunded(id, funder, 3 ether, 3 ether);
        vm.prank(funder);
        t.fundTask{value: 3 ether}(id, 3 ether);

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.FulfillmentSubmitted(id, 1, worker, RES, "ipfs://r", 2);
        vm.prank(worker);
        t.submitFulfillment(id, RES, "ipfs://r");

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.FulfillmentAccepted(id, 1, worker, 1 ether);
        vm.prank(judge);
        t.acceptFulfillment(id, 1);

        vm.prank(worker);
        t.submitFulfillment(id, sha256("d2"), "");
        vm.expectEmit(true, true, true, true);
        emit ITaskTender.FulfillmentRejected(id, 2);
        vm.prank(judge);
        t.rejectFulfillment(id, 2);

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.AcceptanceAuthorityChanged(id, judge, rando);
        vm.prank(judge);
        t.setAcceptanceAuthority(id, rando);

        vm.expectEmit(true, true, true, true);
        emit ITaskToken.TaskFrozen(id);
        vm.prank(publisher);
        t.freezeTask(id);

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.TenderCancelled(id);
        vm.prank(publisher);
        t.cancelTask(id);

        vm.expectEmit(true, true, true, true);
        emit ITaskTender.EscrowReclaimed(id, funder, 2 ether);
        vm.prank(funder);
        t.reclaimEscrow(id);
    }

    function test_document_and_residual_events() public {
        bytes memory doc = "# doc";
        uint256 id = t.mintTask(owner, publisher, judge, sha256(doc), TH, "u", terms());
        vm.expectEmit(true, true, true, true);
        emit IOnchainTaskDocument.TaskDocumentPublished(id, sha256(doc));
        vm.prank(publisher);
        t.publishTaskDocument(id, doc);

        uint256 id2 = mintDefault();
        vm.prank(funder);
        t.fundTask{value: 1 ether}(id2, 1 ether);
        vm.prank(rando);
        (bool ok, ) = payable(t.vaultOf(id2)).call{value: 1 ether}("");
        assertTrue(ok);
        vm.prank(publisher);
        t.cancelTask(id2);
        vm.expectEmit(true, true, true, true);
        emit ITaskTender.ResidualReclaimed(id2, owner, 1 ether);
        vm.prank(owner);
        t.reclaimResidual(id2);
    }

    // ---------------- cancellation stops NEW work; it does not void delivered work
    function test_post_cancellation_closure() public {
        uint256 id = mintDefault();
        vm.prank(funder);
        t.fundTask{value: 3 ether}(id, 3 ether);
        vm.prank(worker);
        t.submitFulfillment(id, RES, "");
        vm.prank(publisher);
        t.cancelTask(id);

        // closed: nothing new comes in, and cancellation is irreversible
        vm.prank(funder);
        vm.expectRevert(); t.fundTask{value: 1 ether}(id, 1 ether);
        vm.prank(worker);
        vm.expectRevert(); t.submitFulfillment(id, sha256("x"), "");
        vm.prank(publisher);
        vm.expectRevert(); t.cancelTask(id);
        // and the money already owed cannot be walked away with
        vm.prank(funder);
        vm.expectRevert(); t.reclaimEscrow(id);
        vm.prank(owner);
        vm.expectRevert(); t.reclaimResidual(id);

        // open: the delivered submission is still judgeable, and still pays
        assertEq(t.pendingOf(id), 1);
        assertEq(t.lockedEscrowOf(id), 1 ether);
        uint256 b = worker.balance;
        vm.prank(judge);
        t.acceptFulfillment(id, 1);
        assertEq(worker.balance - b, 1 ether);
        assertEq(t.pendingOf(id), 0);
        // only now, with nothing outstanding, may the funder be refunded
        vm.prank(funder);
        t.reclaimEscrow(id);
        assertEq(t.escrowBalanceOf(id), 0);
    }

    // ---------------- the judgment deadline: silence is not a free option
    function test_unjudged_claim_after_deadline() public {
        uint256 id = mintDefault();
        vm.prank(funder);
        t.fundTask{value: 2 ether}(id, 2 ether);
        vm.prank(worker);
        uint256 sid = t.submitFulfillment(id, RES, "https://delivery.example/report.pdf");
        // the demander reads the deliverable, then cancels AND goes silent
        vm.prank(publisher);
        t.cancelTask(id);
        vm.expectRevert(); // the window is still open
        t.claimUnjudged(id, sid);

        vm.warp(block.timestamp + 7 days + 1);
        uint256 b = worker.balance;
        vm.expectEmit(true, true, true, false); // permissionless: any caller
        emit ITaskTender.FulfillmentClaimedUnjudged(id, sid, worker, 0);
        t.claimUnjudged(id, sid);
        assertEq(worker.balance - b, 1 ether);
        assertEq(t.completionsOf(id), 1);
        assertEq(uint8(t.submissionOf(id, sid).status),
                 uint8(ITaskTender.SubmissionStatus.Accepted));
        vm.expectRevert(); // not pending any more
        t.claimUnjudged(id, sid);
    }

    // ---------------- machine tenders cannot be bricked by junk submissions
    function test_release_expired_frees_a_squatted_slot() public {
        uint256 id = t.mintTask(owner, publisher, address(hashlock), TD, TH, "u",
                                ITaskTender.TenderTerms(address(0), 1 ether, 1, 0, 0, 0, 0, 7 days));
        vm.prank(funder);
        t.fundTask{value: 1 ether}(id, 1 ether);
        vm.prank(rando);
        uint256 sid = t.submitFulfillment(id, sha256("junk"), "");
        // with no judge to reject it, this one submission holds the only slot and the
        // whole vault: without a release it would freeze the tender forever
        assertEq(t.pendingOf(id), 1);
        assertEq(t.lockedEscrowOf(id), 1 ether);
        vm.expectRevert(); // the window has not elapsed
        t.releaseExpired(id, sid);

        vm.warp(block.timestamp + 7 days + 1);
        vm.expectEmit(true, true, true, false);
        emit ITaskTender.SubmissionReleased(id, sid, 0);
        t.releaseExpired(id, sid); // permissionless
        assertEq(uint8(t.submissionOf(id, sid).status),
                 uint8(ITaskTender.SubmissionStatus.Rejected));
        assertEq(t.pendingOf(id), 0);
        assertEq(t.lockedEscrowOf(id), 0);
        // the tender lives again for a genuine solver
        vm.prank(worker);
        t.submitFulfillment(id, sha256("real attempt"), "");
        assertEq(t.pendingOf(id), 1);
    }

    function test_release_expired_is_machine_path_only() public {
        uint256 id = mintDefault(); // judged
        vm.prank(funder);
        t.fundTask{value: 1 ether}(id, 1 ether);
        vm.prank(worker);
        uint256 sid = t.submitFulfillment(id, RES, "");
        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(); // a judged tender has a judge; silence pays the worker instead
        t.releaseExpired(id, sid);
        t.claimUnjudged(id, sid); // the correct remedy on this path
        assertEq(t.completionsOf(id), 1);
    }

    // ---------------- the default belongs to the judged path only
    function test_unjudged_claim_blocked_on_machine_path() public {
        uint256 id = t.mintTask(owner, publisher, address(hashlock), TD, TH, "u", terms());
        vm.prank(funder);
        t.fundTask{value: 2 ether}(id, 2 ether);
        vm.prank(rando);
        uint256 sid = t.submitFulfillment(id, sha256("garbage"), "");
        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(); // no judge to default: code decides, and code said no
        t.claimUnjudged(id, sid);
    }

    // ---------------- a delivery reserves a slot and a reward
    function test_delivery_reserves_slot_and_reward() public {
        uint256 id = mintDefault(); // maxCompletions = 2
        vm.prank(worker);
        vm.expectRevert(); // an unfunded tender may not take delivery at all
        t.submitFulfillment(id, RES, "");

        vm.prank(funder);
        t.fundTask{value: 1 ether}(id, 1 ether);
        vm.prank(worker);
        t.submitFulfillment(id, RES, "");
        assertEq(t.pendingOf(id), 1);
        assertEq(t.lockedEscrowOf(id), 1 ether);
        vm.prank(worker2);
        vm.expectRevert(); // a second delivery the vault could not pay for
        t.submitFulfillment(id, sha256("d2"), "");

        vm.prank(funder);
        t.fundTask{value: 1 ether}(id, 1 ether);
        vm.prank(worker2);
        t.submitFulfillment(id, sha256("d2"), "");
        assertEq(t.pendingOf(id), 2);
        vm.prank(rando);
        vm.expectRevert(); // both slots are now reserved by delivered work
        t.submitFulfillment(id, sha256("d3"), "");

        // an explicit rejection releases the reservation, on the record
        vm.prank(judge);
        t.rejectFulfillment(id, 2);
        assertEq(t.pendingOf(id), 1);
        assertEq(t.lockedEscrowOf(id), 1 ether);
        vm.prank(rando);
        t.submitFulfillment(id, sha256("d3"), ""); // the freed slot is usable again
        assertEq(t.pendingOf(id), 2);
    }

    // ---------------- freeze binds content, nothing else
    function test_freeze_scope() public {
        uint256 id = mintDefault();
        vm.prank(publisher);
        t.freezeTask(id);
        vm.prank(publisher);
        vm.expectRevert(); t.updateTaskWithDocument(id, "new", TH2);
        vm.prank(publisher);
        t.setUpdateAuthority(id, rando);
        assertEq(t.updateAuthorityOf(id), rando);
        vm.prank(rando);
        t.cancelTask(id);
        assertTrue(t.isTenderCancelled(id));
        assertTrue(t.isTaskFrozen(id)); // cancellation is a tender act, not a binding act
    }

    // ---------------- authority gates not exercised by the primary suite
    function test_authority_gates() public {
        uint256 id = mintDefault();
        vm.prank(rando);
        vm.expectRevert(); t.setTaskURI(id, "x");
        vm.prank(rando);
        vm.expectRevert(); t.setUpdateAuthority(id, rando);
        vm.prank(rando);
        vm.expectRevert(); t.updateTaskWithDocument(id, "d", TH2);
        vm.prank(rando);
        vm.expectRevert(); t.publishTaskDocument(id, "d");
        vm.prank(funder);
        t.fundTask{value: 2 ether}(id, 2 ether);
        vm.prank(worker);
        t.submitFulfillment(id, RES, "");
        vm.prank(rando);
        vm.expectRevert(); t.rejectFulfillment(id, 1);
    }

    // ---------------- operator approval confers nothing (approve() is covered elsewhere)
    function test_operator_approval_confers_nothing() public {
        uint256 id = mintDefault();
        vm.prank(owner);
        t.setApprovalForAll(rando, true);
        assertTrue(t.isApprovedForAll(owner, rando));
        vm.startPrank(rando);
        vm.expectRevert(); t.updateTask(id, TD, TH2);
        vm.expectRevert(); t.freezeTask(id);
        vm.expectRevert(); t.cancelTask(id);
        vm.expectRevert(); t.setTaskURI(id, "x");
        vm.expectRevert(); t.setUpdateAuthority(id, rando);
        vm.expectRevert(); t.setAcceptanceAuthority(id, rando);
        vm.stopPrank();
        // residual: cancel first, so the ONLY thing standing between the operator
        // and the money is the owner check itself
        vm.prank(rando);
        (bool ok, ) = payable(t.vaultOf(id)).call{value: 1 ether}("");
        assertTrue(ok);
        vm.prank(publisher);
        t.cancelTask(id);
        vm.prank(rando);
        vm.expectRevert(); t.reclaimResidual(id);
        uint256 b = owner.balance;
        vm.prank(owner);
        t.reclaimResidual(id);
        assertEq(owner.balance - b, 1 ether); // only the owner, never the operator
        assertEq(t.escrowBalanceOf(id), 0);   // nothing else was in the vault
    }

    // ---------------- a rejected submission is dead on BOTH paths
    function test_rejection_terminal_across_paths() public {
        bytes memory answer = "42";
        uint256 id = t.mintTask(owner, publisher, judge, TD, TH, "u",
                                ITaskTender.TenderTerms(address(0), 1 ether, 3, 0, 0, 0, 0, 7 days));
        vm.prank(funder);
        t.fundTask{value: 3 ether}(id, 3 ether);
        bytes32 commitment = sha256(abi.encodePacked(answer, worker));
        vm.prank(worker);
        uint256 sid = t.submitFulfillment(id, commitment, "");
        vm.prank(judge);
        t.rejectFulfillment(id, sid);

        // judgment migrates from an EOA to a verifier contract: the dead stays dead
        vm.prank(judge);
        t.setAcceptanceAuthority(id, address(hashlock));
        vm.prank(publisher);
        hashlock.commitAnswer(address(t), id, sha256(answer));
        vm.prank(rando);
        vm.expectRevert();
        t.settleFulfillment(id, sid, answer);

        // rejection is per-submission, never a ban on the fulfiller
        vm.prank(worker);
        uint256 sid2 = t.submitFulfillment(id, commitment, "");
        vm.prank(rando);
        t.settleFulfillment(id, sid2, answer);
        assertEq(t.completionsOf(id), 1);
        vm.prank(rando);
        vm.expectRevert(); // an Accepted submission cannot be settled twice
        t.settleFulfillment(id, sid2, answer);
    }

    // ---------------- refunds open on settleBy expiry, not only on cancellation
    function test_reclaim_on_expiry_without_cancellation() public {
        uint256 id = t.mintTask(owner, publisher, judge, TD, TH, "u",
            ITaskTender.TenderTerms(address(0), 1 ether, 0,
                uint64(block.timestamp + 100), uint64(block.timestamp + 200), 0, 0, 7 days));
        vm.prank(funder);
        t.fundTask{value: 2 ether}(id, 2 ether);
        vm.prank(funder2);
        t.fundTask{value: 2 ether}(id, 2 ether);
        vm.prank(funder);
        vm.expectRevert(); t.reclaimEscrow(id);

        vm.warp(block.timestamp + 300);
        uint256 b = funder.balance;
        vm.prank(funder);
        t.reclaimEscrow(id);
        assertEq(funder.balance - b, 2 ether);
        assertFalse(t.isTenderCancelled(id)); // the expiry route, not the cancel route
        vm.prank(funder);
        vm.expectRevert(); t.reclaimEscrow(id); // outstanding contribution is now zero
        assertEq(t.escrowBalanceOf(id), 2 ether); // the other funder is untouched
    }

    // ---------------- maxCompletions == 0 is unbounded
    function test_unbounded_completions() public {
        uint256 id = t.mintTask(owner, publisher, judge, TD, TH, "u",
                                ITaskTender.TenderTerms(address(0), 1 ether, 0, 0, 0, 0, 0, 7 days));
        vm.prank(funder);
        t.fundTask{value: 5 ether}(id, 5 ether);
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(worker);
            t.submitFulfillment(id, sha256(abi.encodePacked("d", i)), "");
        }
        vm.startPrank(judge);
        for (uint256 i = 1; i <= 4; i++) t.acceptFulfillment(id, i);
        vm.stopPrank();
        assertEq(t.completionsOf(id), 4); // the bounded default would have stopped at 2
    }

    // ---------------- native tender: msg.value MUST equal amount
    function test_native_funding_amount_must_match() public {
        uint256 id = mintDefault();
        vm.startPrank(funder);
        vm.expectRevert(); t.fundTask{value: 1 ether}(id, 2 ether);
        vm.expectRevert(); t.fundTask{value: 2 ether}(id, 1 ether);
        vm.expectRevert(); t.fundTask{value: 0}(id, 1 ether);
        vm.stopPrank();
    }

    // ---------------- submission ids are per-token and start at 1
    function test_submission_ids_are_per_token() public {
        uint256 a = mintDefault();
        uint256 b = mintDefault();
        vm.prank(funder);
        t.fundTask{value: 2 ether}(a, 2 ether);
        vm.prank(funder);
        t.fundTask{value: 1 ether}(b, 1 ether);
        vm.startPrank(worker);
        t.submitFulfillment(a, sha256("a1"), "");
        t.submitFulfillment(a, sha256("a2"), "");
        uint256 first = t.submitFulfillment(b, sha256("b1"), "");
        vm.stopPrank();
        assertEq(first, 1); // not 3
        assertEq(t.submissionCountOf(a), 2);
        assertEq(t.submissionCountOf(b), 1);
    }

    // ---------------- remaining views on a nonexistent token
    function test_nonexistent_views_remaining() public {
        vm.expectRevert(); t.submissionOf(4242, 1);
        vm.expectRevert(); t.taskDocument(4242);
        vm.expectRevert(); t.tokenURI(4242);
    }

    // ---------------- state changes precede the asset transfer; contracts can be paid
    function test_cei_and_contract_fulfiller() public {
        ObservingFulfiller f = new ObservingFulfiller(t);
        uint256 id = mintDefault();
        vm.prank(funder);
        t.fundTask{value: 2 ether}(id, 2 ether);
        uint256 sid = f.submit(id, RES);
        vm.prank(judge);
        t.acceptFulfillment(id, sid);
        assertTrue(f.received());                 // not gas-starved by transfer()
        assertEq(f.seenCompletions(), 1);         // effects already applied...
        assertEq(f.seenEscrow(), 1 ether);        // ...including the vault debit
        assertGt(f.gasOnReceive(), 2300);         // real gas forwarded, not the stipend
    }

    // ---------------- nonstandard assets: credit follows the balance difference
    function test_fee_on_transfer_erc20() public {
        FeeERC20 fee = new FeeERC20();
        uint256 id = t.mintTask(owner, publisher, judge, TD, TH, "u",
                                ITaskTender.TenderTerms(address(fee), 50e18, 1, 0, 0, 0, 0, 7 days));
        fee.mint(funder, 500e18);
        vm.prank(funder);
        fee.approve(address(t), 500e18);
        vm.prank(funder);
        t.fundTask(id, 100e18);
        address vault = t.vaultOf(id);
        assertEq(fee.balanceOf(vault), 99e18);              // 1% evaporated in transit
        assertEq(t.escrowBalanceOf(id), fee.balanceOf(vault)); // credit follows reality
        vm.prank(worker);
        uint256 sid = t.submitFulfillment(id, RES, "");
        vm.prank(judge);
        t.acceptFulfillment(id, sid);
        assertGt(fee.balanceOf(worker), 0);
        assertEq(t.escrowBalanceOf(id), fee.balanceOf(vault)); // still exact after a lossy payout
    }

    // ---------------- ERC-20 refund + residual, the paths only proven in native currency
    function test_erc20_refund_and_residual() public {
        MinimalERC20 usd = new MinimalERC20();
        uint256 id = t.mintTask(owner, publisher, judge, TD, TH, "u",
                                ITaskTender.TenderTerms(address(usd), 10e18, 5, 0, 0, 0, 0, 7 days));
        usd.mint(funder, 100e18);
        usd.mint(funder2, 100e18);
        vm.prank(funder);  usd.approve(address(t), 100e18);
        vm.prank(funder2); usd.approve(address(t), 100e18);
        vm.prank(funder);  t.fundTask(id, 30e18);
        vm.prank(funder2); t.fundTask(id, 10e18);
        usd.mint(t.vaultOf(id), 10e18);                     // anonymous ERC-20 gift
        assertEq(t.escrowBalanceOf(id), 50e18);

        vm.prank(worker);
        uint256 sid = t.submitFulfillment(id, RES, "");
        vm.prank(judge);
        t.acceptFulfillment(id, sid);
        assertEq(usd.balanceOf(worker), 10e18);

        vm.prank(publisher);
        t.cancelTask(id);
        vm.prank(funder);  t.reclaimEscrow(id);
        vm.prank(funder2); t.reclaimEscrow(id);
        // the gift absorbed the whole reward, so both funders are made whole
        assertEq(usd.balanceOf(funder), 100e18);
        assertEq(usd.balanceOf(funder2), 100e18);
        assertEq(t.escrowBalanceOf(id), 0);
        vm.prank(owner);
        vm.expectRevert(); // gift fully consumed: there is no residual to take
        t.reclaimResidual(id);
    }
}
