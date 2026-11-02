// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/// @notice Prototype of docs/v2-admission-slot.md; not part of the filed v1 ERC.
interface ITaskAdmission {
    function admit(address taskContract, uint256 tokenId, address submitter, bytes32 resultHash,
        uint64 taskVersion) external view returns (bool);
}
