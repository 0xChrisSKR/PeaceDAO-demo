// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernance {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    struct ProposalView {
        uint256 id;
        address proposer;
        address recipient;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 validatorLikes;
        uint256 validatorDislikes;
        bool finalized;
        bool passed;
        bool executed;
    }

    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed recipient,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed id,
        address indexed voter,
        VoteType support,
        uint256 weight,
        string reason
    );

    event ValidationCast(uint256 indexed id, address indexed validator, bool likeIt);

    event ProposalFinalized(
        uint256 indexed id,
        bool passed,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 validatorLikes,
        uint256 validatorDislikes
    );

    event DonationExecuted(uint256 indexed id, address indexed recipient, uint256 amount);

    function createProposal(
        address payable recipient,
        string calldata title,
        string calldata description,
        uint256 votingPeriod
    ) external returns (uint256);

    function vote(uint256 id, VoteType support, string calldata reason) external;

    function validate(uint256 id, bool likeIt) external;

    function finalize(uint256 id) external;

    function executeDonation(uint256 id) external;

    function getProposal(uint256 id) external view returns (ProposalView memory);

    function hasVoted(uint256 id, address account) external view returns (bool);

    function hasValidated(uint256 id, address account) external view returns (bool);

    function proposalFinalized(uint256 id) external view returns (bool);

    function proposalPassed(uint256 id) external view returns (bool);
}
