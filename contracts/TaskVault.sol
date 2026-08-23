// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface IERC20Payout {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title  TaskVault — per-token locked bounty vault (TASK-KERNEL v3.0).
/// @notice One vault per task token, deployed at mint. The vault is the reverse
///         asset's credit foundation: its balance is directly visible to any
///         explorer, anyone can deposit (deposits count as escrow), and funds can
///         leave ONLY at the instruction of the controlling task contract, which
///         itself only instructs payouts through settlement and refund.
///         There is no owner, no upgrade path, and no other exit.
/// @dev    Reference mechanism satisfying the standard's vault invariants; an
///         ERC-6551 token-bound account with a locked implementation (owner
///         execution stripped) satisfies them equally and is the recommended
///         profile for token-bound-account composability.
contract TaskVault {
    address public immutable controller;

    constructor() {
        controller = msg.sender; // the TaskToken contract deploying this vault
    }

    /// @notice Anyone may deposit native assets directly; such deposits are
    ///         unattributed bounty gifts (see the standard's refund rules).
    receive() external payable {}

    /// @notice Release funds. Controller-only; the controller's settlement and
    ///         refund logic are the sole callers.
    function payout(address asset, address to, uint256 amount) external {
        require(msg.sender == controller, "TaskVault: not controller");
        require(tryPayout(asset, to, amount), "TaskVault: payout failed");
    }

    /// @notice Attempt a payout and report the outcome instead of reverting on a
    ///         recipient that will not take the money. A settlement must not be made
    ///         to depend on the recipient's willingness to receive: a contract with a
    ///         reverting fallback would otherwise wedge the submission forever and,
    ///         with it, every refund behind it. The controller credits the amount for
    ///         later withdrawal when this returns false.
    function tryPayout(address asset, address to, uint256 amount) public returns (bool) {
        require(msg.sender == controller, "TaskVault: not controller");
        if (asset == address(0)) {
            (bool ok, ) = payable(to).call{value: amount, gas: 30000}("");
            return ok;
        }
        (bool called, bytes memory data) =
            asset.call(abi.encodeWithSelector(IERC20Payout.transfer.selector, to, amount));
        return called && (data.length == 0 || abi.decode(data, (bool)));
    }
}
