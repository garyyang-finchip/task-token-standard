// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/// @title  Fixtures for scripts/smoke.mjs.
/// @notice Not part of the standard and not part of the reference implementation.
///         These three contracts exist so that `local_e2e.sh` can prove the payout
///         paths on a real chain without Foundry. They mirror the fixtures in
///         `test/TaskTokenCoverage.t.sol`; keeping them compilable by solc-js is what
///         makes the smoke suite runnable from a fresh clone.

interface ITaskSmoke {
    function submitFulfillment(uint256 tokenId, bytes32 resultHash, string calldata resultURI)
        external returns (uint256);
    function completionsOf(uint256 tokenId) external view returns (uint64);
    function escrowBalanceOf(uint256 tokenId) external view returns (uint256);
}

/// A contract fulfiller that refuses payment outright: a multisig with a guard, a
/// splitter with a bug, a proxy whose implementation was swapped.
contract RevertingFulfiller {
    function submit(address t, uint256 id, bytes32 rh) external returns (uint256) {
        return ITaskSmoke(t).submitFulfillment(id, rh, "");
    }
    receive() external payable { revert("nope"); }
}

/// An ordinary, well-behaved contract fulfiller: it records the payment and reads the
/// tender back. Four cold writes and two external calls -- unremarkable for a wallet
/// or a team splitter, and far more than a 2300-gas stipend or a 30_000 cap allows.
contract ObservingFulfiller {
    ITaskSmoke public t;
    uint256 public tokenId;
    uint256 public seenCompletions;
    uint256 public seenEscrow;
    uint256 public gasOnReceive;
    bool public received;

    constructor(address _t) { t = ITaskSmoke(_t); }

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

/// A fulfiller whose receive hook is genuinely too expensive for any bounded push.
/// It is not hostile -- it simply costs more than the settling party should be asked
/// to pay -- and it is the case the credit path has to make whole.
contract HeavyFulfiller {
    ITaskSmoke public t;
    uint256[40] public slots;
    uint256 public taken;

    constructor(address _t) { t = ITaskSmoke(_t); }

    function submit(uint256 id, bytes32 rh) external returns (uint256) {
        return t.submitFulfillment(id, rh, "");
    }

    receive() external payable {
        taken += msg.value;
        for (uint256 i = 0; i < 40; i++) slots[i] = i + 1;
    }
}
