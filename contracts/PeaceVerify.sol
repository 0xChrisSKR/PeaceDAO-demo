// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPeaceDAOVerifier {
    function recordDonationVerifier(uint256 proposalId, address verifier) external;
}

contract PeaceVerify {
    address public owner;
    address public immutable dao;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DonationVerified(uint256 indexed proposalId, address indexed verifier);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address dao_) {
        require(dao_ != address(0), "dao=0");
        owner = msg.sender;
        dao = dao_;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice 記錄驗證成功並告知 DAO 支付對應驗證者獎勵
    function submitVerification(uint256 proposalId, address verifier) external onlyOwner {
        require(verifier != address(0), "verifier=0");
        IPeaceDAOVerifier(dao).recordDonationVerifier(proposalId, verifier);
        emit DonationVerified(proposalId, verifier);
    }
}
