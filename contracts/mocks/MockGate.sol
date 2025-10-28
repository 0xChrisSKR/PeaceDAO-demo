// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockGate {
    mapping(address => bool) public voters;
    mapping(address => bool) public proposers;

    function setVoter(address user, bool allowed) external {
        voters[user] = allowed;
    }

    function setProposer(address user, bool allowed) external {
        proposers[user] = allowed;
    }

    function hasVote(address user) external view returns (bool) {
        return voters[user];
    }

    function hasProp(address user) external view returns (bool) {
        return proposers[user];
    }
}
