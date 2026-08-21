// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/// @title  Token-Bound Task Tenders — tender interface (TASK-KERNEL v2.0), own ERC-165 id.
/// @notice The reverse-asset layer: per-token bounty vault, immutable terms, bounded
///         and optionally epoch-paced completion, machine or judged settlement, refund.
///         The kernel enforces arithmetic (counting, pacing, solvency, deadlines,
///         authority); the acceptance authority enforces semantics.
interface ITaskTender {
    struct TenderTerms {
        address asset;                  // reward asset; address(0) = chain-native currency
        uint256 rewardPerCompletion;    // paid per accepted completion; MUST be > 0
        uint64  maxCompletions;         // completion bound; 0 = unbounded
        uint64  submitBy;               // unix seconds; no submissions after; 0 = none
        uint64  settleBy;               // unix seconds; no settlements after, refunds unlock; 0 = none
        uint64  epochLength;            // seconds per epoch; 0 = no cadence
        uint64  maxCompletionsPerEpoch; // per-epoch settlement bound; MUST be 0 iff epochLength == 0
    }

    enum SubmissionStatus { Pending, Accepted, Rejected }

    struct Submission {
        address          fulfiller;   // address of record; MAY be a team splitter or rights contract
        bytes32          resultHash;  // deliverable commitment; opaque except per acceptance/delivery profile
        uint64           taskVersion; // binding version cited at submission time
        SubmissionStatus status;
    }

    event TenderFunded(uint256 indexed tokenId, address indexed funder,
                       uint256 amount, uint256 escrowBalance);
    event TenderCancelled(uint256 indexed tokenId);
    event EscrowReclaimed(uint256 indexed tokenId, address indexed funder, uint256 amount);
    event ResidualReclaimed(uint256 indexed tokenId, address indexed owner, uint256 amount);
    event AcceptanceAuthorityChanged(uint256 indexed tokenId,
                                     address indexed previousAuthority,
                                     address indexed newAuthority);
    event FulfillmentSubmitted(uint256 indexed tokenId, uint256 indexed submissionId,
                               address indexed fulfiller, bytes32 resultHash,
                               string resultURI, uint64 taskVersion);
    event FulfillmentAccepted(uint256 indexed tokenId, uint256 indexed submissionId,
                              address indexed fulfiller, uint256 reward);
    event FulfillmentRejected(uint256 indexed tokenId, uint256 indexed submissionId);

    /// @notice The token's bounty vault: a distinct per-token account, visible to
    ///         anyone, spendable by no one, released only through settlement/refund.
    function vaultOf(uint256 tokenId) external view returns (address);
    function tenderTermsOf(uint256 tokenId) external view returns (TenderTerms memory);
    function acceptanceAuthorityOf(uint256 tokenId) external view returns (address);
    /// @notice MUST equal the vault's live balance in the tender asset.
    function escrowBalanceOf(uint256 tokenId) external view returns (uint256);
    function completionsOf(uint256 tokenId) external view returns (uint64);
    function completionsInEpochOf(uint256 tokenId, uint64 epoch) external view returns (uint64);
    function isTenderCancelled(uint256 tokenId) external view returns (bool);
    function submissionCountOf(uint256 tokenId) external view returns (uint256);
    function submissionOf(uint256 tokenId, uint256 submissionId)
        external view returns (Submission memory);

    /// @notice Fund the tender's vault. Callable by anyone (bounty pooling), attributed
    ///         for refunds. Direct transfers to the vault count as unattributed gifts.
    function fundTask(uint256 tokenId, uint256 amount) external payable;

    /// @notice Record a fulfillment commitment. Permissionless at this layer.
    function submitFulfillment(uint256 tokenId, bytes32 resultHash, string calldata resultURI)
        external returns (uint256 submissionId);

    /// @notice Judged settlement path. Only the acceptance authority.
    function acceptFulfillment(uint256 tokenId, uint256 submissionId) external;

    /// @notice Machine settlement path: callable by ANYONE when the acceptance
    ///         authority declares ITaskVerifier via ERC-165. Reverts unless the
    ///         verifier returns true; a failed verification is NOT a rejection.
    function settleFulfillment(uint256 tokenId, uint256 submissionId, bytes calldata proof) external;

    /// @notice Terminal per submission; judged path only; moves no assets.
    function rejectFulfillment(uint256 tokenId, uint256 submissionId) external;

    /// @notice Transfer the judgment right. Zero address forbidden.
    function setAcceptanceAuthority(uint256 tokenId, address newAuthority) external;

    /// @notice Irreversibly terminate the tender (update authority only).
    function cancelTask(uint256 tokenId) external;

    /// @notice Reclaim a funder's pro-rata share of the remaining ATTRIBUTED pool.
    ///         Only when cancelled, or after a nonzero settleBy has passed.
    function reclaimEscrow(uint256 tokenId) external;

    /// @notice Reclaim the vault's residual — unattributed gifts and rounding dust —
    ///         to the token OWNER. Same gate as reclaimEscrow. Rewards consume gifts
    ///         before attributed funds, so the residual is whatever gifting the
    ///         completed work did not spend.
    function reclaimResidual(uint256 tokenId) external;
}
