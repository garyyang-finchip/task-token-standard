// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

interface ITaskSubmit {
    function submitFulfillment(uint256 tokenId, bytes32 resultHash, string calldata resultURI)
        external returns (uint256);
}

/// @title  FixedSplitter — a team's fulfiller of record.
/// @notice The standard needs nothing special to support collaborative delivery: the
///         fulfiller is an address, and an address may be a contract. This is that
///         contract. Shares are fixed at construction, the reward arrives as an
///         ordinary payment, and each member withdraws their own share.
///
///         Pull payments on purpose. A push loop would let one member's reverting
///         receiver block everyone else's money, and would put the team's internal
///         arrangement in the path of the tender's settlement, which is exactly what
///         the kernel keeps out of its own path.
contract FixedSplitter {
    address[] public members;
    uint256[] public shares;      // in basis points, summing to 10_000
    uint256 public totalReceived; // lifetime, so late arrivals are shared correctly
    mapping(address => uint256) public withdrawn;

    event Received(address indexed from, uint256 amount, uint256 totalReceived);
    event Withdrawn(address indexed member, uint256 amount);

    constructor(address[] memory members_, uint256[] memory shares_) {
        require(members_.length == shares_.length && members_.length > 0, "Splitter: shape");
        uint256 sum;
        for (uint256 i = 0; i < members_.length; i++) {
            require(members_[i] != address(0), "Splitter: zero member");
            require(shares_[i] > 0, "Splitter: zero share");
            sum += shares_[i];
        }
        require(sum == 10_000, "Splitter: shares must total 10000 bps");
        members = members_;
        shares = shares_;
    }

    receive() external payable {
        totalReceived += msg.value;
        emit Received(msg.sender, msg.value, totalReceived);
    }

    function memberCount() external view returns (uint256) { return members.length; }

    /// @notice Deliver on the team's behalf, so that the fulfiller of record is this
    ///         contract and the reward lands where the shares are defined. Only a
    ///         member may commit the team; the kernel sees one address, as always.
    function submitOnBehalf(address taskToken, uint256 tokenId, bytes32 resultHash,
                            string calldata resultURI)
        external returns (uint256 submissionId)
    {
        require(_sharesOf(msg.sender) > 0, "Splitter: not a member");
        return ITaskSubmit(taskToken).submitFulfillment(tokenId, resultHash, resultURI);
    }

    /// @notice What `member` may withdraw right now.
    function releasable(address member) public view returns (uint256) {
        uint256 bps = _sharesOf(member);
        if (bps == 0) return 0;
        return (totalReceived * bps) / 10_000 - withdrawn[member];
    }

    /// @notice Take your share. Anyone may trigger it for anyone; the money only ever
    ///         goes to the member it belongs to.
    function withdraw(address member) external {
        uint256 amount = releasable(member);
        require(amount > 0, "Splitter: nothing releasable");
        withdrawn[member] += amount;                      // effects before interaction
        emit Withdrawn(member, amount);
        (bool ok, ) = payable(member).call{value: amount}("");
        require(ok, "Splitter: transfer failed");
    }

    function _sharesOf(address member) private view returns (uint256) {
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == member) return shares[i];
        }
        return 0;
    }
}
