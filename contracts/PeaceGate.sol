// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * PeaceGate
 * Token-verified access roles:
 * - READER  : can view / join chat
 * - VOTER   : can vote
 * - PROPOSER: can create proposals
 * Thresholds adjustable by owner.
 */
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    constructor() { owner = msg.sender; }
    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

contract PeaceGate is Ownable {
    IERC20 public immutable token;

    uint256 public tierRead;      // read / talk
    uint256 public tierVote;      // vote
    uint256 public tierPropose;   // propose / committee

    mapping(address => bool) public blacklist;

    event ThresholdsUpdated(uint256 readReq, uint256 voteReq, uint256 proposeReq);
    event BlacklistUpdated(address indexed user, bool blocked);

    enum Role { NONE, READER, VOTER, PROPOSER }

    constructor(address token_) {
        require(token_ != address(0), "token=0");
        token = IERC20(token_);
        tierRead = 1e18;       // 1 token
        tierVote = 10e18;      // 10 tokens
        tierPropose = 100e18;  // 100 tokens
    }

    function setThresholds(
        uint256 _read,
        uint256 _vote,
        uint256 _propose
    ) external onlyOwner {
        require(_read <= _vote && _vote <= _propose, "order");
        tierRead = _read;
        tierVote = _vote;
        tierPropose = _propose;
        emit ThresholdsUpdated(_read, _vote, _propose);
    }

    function setBlacklist(address user, bool blocked) external onlyOwner {
        blacklist[user] = blocked;
        emit BlacklistUpdated(user, blocked);
    }

    function roleOf(address user) public view returns (Role) {
        if (blacklist[user]) return Role.NONE;
        uint256 bal = token.balanceOf(user);
        if (bal >= tierPropose) return Role.PROPOSER;
        if (bal >= tierVote) return Role.VOTER;
        if (bal >= tierRead) return Role.READER;
        return Role.NONE;
    }

    function hasReadAccess(address u) external view returns (bool) { return roleOf(u) >= Role.READER; }
    function hasVoteAccess(address u) external view returns (bool) { return roleOf(u) >= Role.VOTER; }
    function hasProposeAccess(address u) external view returns (bool) { return roleOf(u) >= Role.PROPOSER; }
}
