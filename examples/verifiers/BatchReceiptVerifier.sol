// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

import {ITaskVerifier} from "../../contracts/interfaces/ITaskVerifier.sol";
import {ITaskTender} from "../../contracts/interfaces/ITaskTender.sol";

interface IUpdateAuthorityView {
    function updateAuthorityOf(uint256 tokenId) external view returns (address);
}

/// @title  BatchReceiptVerifier — machine settlement for assigned-batch work
///         (profile: `x-batch-receipt-merkle-minage-v1`).
///
/// @notice A hardened alternative to a single shared hashlock, for the common
///         commercial shape where a demander splits work into batches, assigns each
///         batch to a known fulfiller, and can check each batch mechanically — QA
///         against hidden gold-standard items, a graded test set, an oracle-confirmed
///         measurement. The demander knows every answer in advance; the fulfiller can
///         only obtain one by actually doing that batch.
///
/// Two properties a single-secret hashlock cannot give:
///
/// 1. **One secret per claim.** The demander commits a Merkle root over leaves
///    `sha256(receipt_i ‖ fulfiller_i)`. Revealing batch A's receipt proves nothing
///    about batch B, and it cannot even be replayed against batch B, because the leaf
///    binds the fulfiller who was assigned that batch. With a shared answer, the first
///    settlement hands every remaining claim to whoever is watching the mempool.
///
/// 2. **A minimum submission age.** Settlement is refused until the submission has
///    existed for `minAge` seconds. An observer who copies a revealed receipt must
///    first post their own submission and then wait, by which time the honest claim
///    has settled. This reads `submittedAt` from the task contract — the field the
///    standard added precisely so that a verifier can price the passage of time.
///
/// The proof is `abi.encode(bytes receipt, bytes32[] merkleProof)`.
contract BatchReceiptVerifier is ITaskVerifier {
    struct Commitment {
        bytes32 root;    // Merkle root over sha256(receipt ‖ fulfiller) leaves
        uint64  minAge;  // seconds a submission must exist before it may settle
    }

    mapping(bytes32 => Commitment) public commitmentOf; // key(taskContract, tokenId)

    event BatchRootCommitted(address indexed taskContract, uint256 indexed tokenId,
                             bytes32 root, uint64 minAge);

    function key(address taskContract, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(taskContract, tokenId));
    }

    /// @notice Commit the batch receipts for a task. Only that task's update authority,
    ///         and set-once: a changed answer set would be a changed task.
    function commitBatchRoot(address taskContract, uint256 tokenId, bytes32 root, uint64 minAge)
        external
    {
        require(root != bytes32(0), "BatchReceipt: zero root");
        require(minAge > 0, "BatchReceipt: zero minAge");
        require(
            msg.sender == IUpdateAuthorityView(taskContract).updateAuthorityOf(tokenId),
            "BatchReceipt: not update authority"
        );
        bytes32 k = key(taskContract, tokenId);
        require(commitmentOf[k].root == bytes32(0), "BatchReceipt: already committed");
        commitmentOf[k] = Commitment(root, minAge);
        emit BatchRootCommitted(taskContract, tokenId, root, minAge);
    }

    /// @inheritdoc ITaskVerifier
    function verifyFulfillment(
        address taskContract,
        uint256 tokenId,
        uint256 submissionId,
        address fulfiller,
        bytes32 resultHash,
        bytes calldata proof
    ) external view returns (bool) {
        Commitment memory c = commitmentOf[key(taskContract, tokenId)];
        if (c.root == bytes32(0)) return false;

        // the submission must have been standing long enough that a mempool observer
        // could not have produced it after seeing this very proof
        ITaskTender.Submission memory s =
            ITaskTender(taskContract).submissionOf(tokenId, submissionId);
        if (block.timestamp < uint256(s.submittedAt) + c.minAge) return false;

        (bytes memory receipt, bytes32[] memory branch) = abi.decode(proof, (bytes, bytes32[]));
        // the claim is the leaf: the receipt for THIS fulfiller's batch
        bytes32 leaf = sha256(abi.encodePacked(receipt, fulfiller));
        if (resultHash != leaf) return false;
        return _root(leaf, branch) == c.root;
    }

    /// Sorted-pair SHA-256 Merkle root. SHA-256 rather than keccak keeps every hash in
    /// this standard's surface one primitive; sorted pairs make the branch order-free.
    function _root(bytes32 leaf, bytes32[] memory branch) private pure returns (bytes32 h) {
        h = leaf;
        for (uint256 i = 0; i < branch.length; i++) {
            h = h <= branch[i] ? sha256(abi.encodePacked(h, branch[i]))
                               : sha256(abi.encodePacked(branch[i], h));
        }
    }

    // ---- ERC-165: declares ITaskVerifier so task contracts enable settleFulfillment
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(ITaskVerifier).interfaceId;
    }
}
