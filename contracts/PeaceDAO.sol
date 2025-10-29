// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IGovernance.sol";

interface IERC20Meta {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IFund {
    function transferNative(address to, uint256 amount, uint256 proposalId) external;
    function balance() external view returns (uint256);
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract PeaceDAO is Ownable, IGovernance {
    IERC20Meta public immutable token;
    IFund public immutable fund;

    uint256 public MIN_TOKENS_PROPOSE = 1_000_000 ether;
    uint256 public MIN_TOKENS_VOTE = 200_000 ether;
    uint256 public MIN_TOKENS_VALIDATE = 15_000 ether;

    uint256 public quorumBps = 1_000;
    uint256 public passRatioBps = 6_000;
    uint256 public likeRatioBps = 5_500;

    struct Proposal {
        uint256 id;
        address proposer;
        address payable recipient;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 validatorLikes;
        uint256 validatorDislikes;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) hasValidated;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => bool) private _finalized;
    mapping(uint256 => bool) private _passed;

    event ThresholdsUpdated(uint256 proposeThreshold, uint256 voteThreshold, uint256 validateThreshold);
    event GovernanceParamsUpdated(uint256 quorumBps, uint256 passRatioBps, uint256 likeRatioBps);

    constructor(address token_, address fund_) {
        require(token_ != address(0) && fund_ != address(0), "zero");
        token = IERC20Meta(token_);
        fund = IFund(fund_);
    }

    modifier validProposal(uint256 id) {
        require(id > 0 && id <= proposalCount, "invalid id");
        _;
    }

    function setThresholds(uint256 proposeThreshold, uint256 voteThreshold, uint256 validateThreshold) external onlyOwner {
        MIN_TOKENS_PROPOSE = proposeThreshold;
        MIN_TOKENS_VOTE = voteThreshold;
        MIN_TOKENS_VALIDATE = validateThreshold;
        emit ThresholdsUpdated(proposeThreshold, voteThreshold, validateThreshold);
    }

    function setGovernParams(uint256 quorumBps_, uint256 passRatioBps_, uint256 likeRatioBps_) external onlyOwner {
        require(quorumBps_ <= 10_000, "quorum too high");
        require(passRatioBps_ <= 10_000, "pass too high");
        require(likeRatioBps_ <= 10_000, "like too high");
        quorumBps = quorumBps_;
        passRatioBps = passRatioBps_;
        likeRatioBps = likeRatioBps_;
        emit GovernanceParamsUpdated(quorumBps_, passRatioBps_, likeRatioBps_);
    }

    function createProposal(
        address payable recipient,
        string calldata title,
        string calldata description,
        uint256 votingPeriod
    ) external override returns (uint256 id) {
        require(recipient != address(0), "recipient=0");
        require(votingPeriod > 0, "votingPeriod=0");
        require(token.balanceOf(msg.sender) >= MIN_TOKENS_PROPOSE, "insufficient proposer balance");

        id = ++proposalCount;
        Proposal storage p = _proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.recipient = recipient;
        p.title = title;
        p.description = description;
        p.startTime = block.timestamp;
        p.endTime = p.startTime + votingPeriod;

        emit ProposalCreated(id, msg.sender, recipient, title, description, p.startTime, p.endTime);
    }

    function vote(uint256 id, VoteType support, string calldata reason) external override validProposal(id) {
        Proposal storage p = _proposals[id];
        require(block.timestamp >= p.startTime && block.timestamp <= p.endTime, "voting closed");
        require(!p.hasVoted[msg.sender], "already voted");

        uint256 weight = token.balanceOf(msg.sender);
        require(weight >= MIN_TOKENS_VOTE, "insufficient voter balance");

        p.hasVoted[msg.sender] = true;

        if (support == VoteType.For) {
            p.forVotes += weight;
        } else if (support == VoteType.Against) {
            p.againstVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(id, msg.sender, support, weight, reason);
    }

    function validate(uint256 id, bool likeIt) external override validProposal(id) {
        Proposal storage p = _proposals[id];
        require(block.timestamp > p.endTime, "voting not ended");
        require(!_finalized[id], "finalized");
        require(!p.hasValidated[msg.sender], "already validated");
        require(token.balanceOf(msg.sender) >= MIN_TOKENS_VALIDATE, "insufficient validator balance");

        p.hasValidated[msg.sender] = true;
        if (likeIt) {
            p.validatorLikes += 1;
        } else {
            p.validatorDislikes += 1;
        }

        emit ValidationCast(id, msg.sender, likeIt);
    }

    function finalize(uint256 id) external override validProposal(id) {
        Proposal storage p = _proposals[id];
        require(block.timestamp > p.endTime, "voting not ended");
        require(!_finalized[id], "finalized");

        uint256 totalVotes = p.forVotes + p.againstVotes + p.abstainVotes;
        uint256 totalSupply = token.totalSupply();
        bool reachedQuorum = totalSupply == 0
            ? false
            : totalVotes * 10_000 >= totalSupply * quorumBps;

        uint256 countedVotes = p.forVotes + p.againstVotes;
        bool reachedPass = countedVotes > 0
            && p.forVotes * 10_000 >= passRatioBps * countedVotes;

        uint256 validationVotes = p.validatorLikes + p.validatorDislikes;
        bool reachedLike = validationVotes > 0
            && p.validatorLikes * 10_000 >= likeRatioBps * validationVotes;

        bool passed = reachedQuorum && reachedPass && reachedLike;
        _finalized[id] = true;
        _passed[id] = passed;

        emit ProposalFinalized(id, passed, p.forVotes, p.againstVotes, p.abstainVotes, p.validatorLikes, p.validatorDislikes);
    }

    function executeDonation(uint256 id) external override validProposal(id) {
        Proposal storage p = _proposals[id];
        require(_finalized[id], "not finalized");
        require(_passed[id], "not passed");
        require(!p.executed, "executed");

        uint256 amount = fund.balance();
        require(amount > 0, "no funds");

        p.executed = true;
        fund.transferNative(p.recipient, amount, id);

        emit DonationExecuted(id, p.recipient, amount);
    }

    function getProposal(uint256 id) external view override validProposal(id) returns (ProposalView memory view_) {
        Proposal storage p = _proposals[id];
        view_ = ProposalView({
            id: p.id,
            proposer: p.proposer,
            recipient: p.recipient,
            title: p.title,
            description: p.description,
            startTime: p.startTime,
            endTime: p.endTime,
            forVotes: p.forVotes,
            againstVotes: p.againstVotes,
            abstainVotes: p.abstainVotes,
            validatorLikes: p.validatorLikes,
            validatorDislikes: p.validatorDislikes,
            finalized: _finalized[id],
            passed: _passed[id],
            executed: p.executed
        });
    }

    function hasVoted(uint256 id, address account) external view override validProposal(id) returns (bool) {
        return _proposals[id].hasVoted[account];
    }

    function hasValidated(uint256 id, address account) external view override validProposal(id) returns (bool) {
        return _proposals[id].hasValidated[account];
    }

    function proposalFinalized(uint256 id) external view override validProposal(id) returns (bool) {
        return _finalized[id];
    }

    function proposalPassed(uint256 id) external view override validProposal(id) returns (bool) {
        return _passed[id];
    }
}
