// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.24;

/// @title  DemoUSD — a points-style settlement token for the worked examples.
/// @notice NOT a stablecoin, NOT redeemable, NOT collateralised, and not intended
///         for any use outside these demonstrations. It exists so that the examples
///         can price professional work in units that do not move against the work
///         between award and delivery, which is the actual commercial reason a
///         services tender is denominated in a stable unit rather than in ether.
///
///         Zero decimals on purpose: one unit is one point. In the examples a point
///         stands for 1/100,000 USD, so an 18,000-point engagement fee is about
///         eighteen US cents of notional — play money, priced like the real thing.
contract DemoUSD {
    string public constant name = "Demo USD (points)";
    string public constant symbol = "DUSD";
    uint8  public constant decimals = 0;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Open faucet: this token has no value to protect.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "DUSD: allowance");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) private {
        require(balanceOf[from] >= amount, "DUSD: balance");
        unchecked { balanceOf[from] -= amount; }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
