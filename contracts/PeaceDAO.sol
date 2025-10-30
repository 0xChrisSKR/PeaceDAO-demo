// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovernance} from "./interfaces/IGovernance.sol";
import {IERC20} from "./interfaces/IERC20.sol";

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
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

    uint256 public constant CREATE_THRESHOLD = 1_000_000 ether;
    uint256 public constant VOTE_THRESHOLD = 200_000 ether;
    uint256 public constant VALIDATOR_THRESHOLD = 15_000 ether;

    IERC20 public immutable token;
    address public treasury;

    uint256 public quorum;
    uint256 public passRatioBps;
    uint256 public minValidatorLikes;

    struct Payout {
        address token;
        address payable to;
        uint256 amount;
    }

    struct Proposal {
        address proposer;
        uint64 startTs;
        uint64 endTs;
        Payout payout;
        bool finalized;
        bool passed;
        bool executed;
        uint256 forVotes;
        uint256 againstVotes;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public hasValidated;
    mapping(uint256 => mapping(address => uint256)) public stakeOf;
    mapping(uint256 => uint256) public likeCount;
    mapping(uint256 => uint256) public dislikeCount;

    event TreasurySet(address indexed treasury);
    event GovernanceParamsUpdated(uint256 quorum, uint256 passRatioBps, uint256 minValidatorLikes);
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address indexed payoutToken,
        address payable recipient,
        uint256 amount,
        uint256 startTs,
        uint256 endTs
    );
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 stakeAmount);
    event ValidationCast(uint256 indexed id, address indexed validator, bool likeIt);
    event ProposalFinalized(
        uint256 indexed id,
        bool passed,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 likes,
        uint256 dislikes
    );
    event StakeClaimed(uint256 indexed id, address indexed voter, uint256 amount);
    event ProposalExecuted(uint256 indexed id);

    constructor(address token_) {
        require(token_ != address(0), "token=0");
        token = IERC20(token_);

        quorum = 1_000_000 ether;
        passRatioBps = 6_000;
        minValidatorLikes = 50;
    }

    function setTreasury(address treasury_) external onlyOwner {
        require(treasury_ != address(0), "treasury=0");
        require(treasury == address(0), "treasury set");
        treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    function setGovernanceParams(
        uint256 quorum_,
        uint256 passRatioBps_,
        uint256 minValidatorLikes_
    ) external onlyOwner {
        require(passRatioBps_ <= 10_000, "ratio too high");
        quorum = quorum_;
        passRatioBps = passRatioBps_;
        minValidatorLikes = minValidatorLikes_;
        emit GovernanceParamsUpdated(quorum_, passRatioBps_, minValidatorLikes_);
    }

    function proposePayout(address payoutToken, address payable to, uint256 amount)
        external
        returns (uint256 id)
    {
        require(token.balanceOf(msg.sender) >= CREATE_THRESHOLD, "need 1,000,000 to propose");
        require(to != address(0), "recipient=0");

        id = ++proposalCount;
        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.startTs = uint64(block.timestamp);
        p.endTs = uint64(block.timestamp + 1 days);
        p.payout = Payout({token: payoutToken, to: to, amount: amount});

        emit ProposalCreated(id, msg.sender, payoutToken, to, amount, p.startTs, p.endTs);
    }

    function vote(uint256 id, bool support, uint256 stakeAmount) external {
        Proposal storage p = _proposal(id);
        require(block.timestamp >= p.startTs, "not started");
        require(block.timestamp < p.endTs, "voting closed");
        require(!hasVoted[id][msg.sender], "already voted");
        require(stakeAmount >= VOTE_THRESHOLD, "stake too low");

        hasVoted[id][msg.sender] = true;
        stakeOf[id][msg.sender] = stakeAmount;

        require(token.transferFrom(msg.sender, address(this), stakeAmount), "transferFrom failed");

        if (support) {
            p.forVotes += stakeAmount;
        } else {
            p.againstVotes += stakeAmount;
        }

        emit VoteCast(id, msg.sender, support, stakeAmount);
    }

    function validate(uint256 id, bool likeIt) external {
        Proposal storage p = _proposal(id);
        require(block.timestamp >= p.startTs, "not started");
        require(block.timestamp < p.endTs, "validation closed");
        require(!hasValidated[id][msg.sender], "already validated");
        require(token.balanceOf(msg.sender) >= VALIDATOR_THRESHOLD, "need 15,000 to validate");

        hasValidated[id][msg.sender] = true;
        if (likeIt) {
            likeCount[id] += 1;
        } else {
            dislikeCount[id] += 1;
        }

        emit ValidationCast(id, msg.sender, likeIt);
    }

    function finalize(uint256 id) external {
        Proposal storage p = _proposal(id);
        require(block.timestamp >= p.endTs, "voting not ended");
        require(!p.finalized, "finalized");

        uint256 totalVotes = p.forVotes + p.againstVotes;
        bool reachedQuorum = totalVotes >= quorum;
        bool reachedPass = totalVotes > 0 && p.forVotes * 10_000 >= passRatioBps * totalVotes;
        bool validatorsOk = likeCount[id] >= minValidatorLikes && likeCount[id] >= dislikeCount[id];

        p.finalized = true;
        p.passed = reachedQuorum && reachedPass && validatorsOk;

        emit ProposalFinalized(id, p.passed, p.forVotes, p.againstVotes, likeCount[id], dislikeCount[id]);
    }

    function claimStake(uint256 id) external {
        Proposal storage p = _proposal(id);
        require(block.timestamp >= p.endTs, "voting not ended");

        uint256 amount = stakeOf[id][msg.sender];
        require(amount > 0, "no stake");
        stakeOf[id][msg.sender] = 0;

        require(token.transfer(msg.sender, amount), "transfer failed");
        emit StakeClaimed(id, msg.sender, amount);
    }

    function markProposalExecuted(uint256 id) external {
        require(msg.sender == treasury, "only treasury");
        Proposal storage p = _proposal(id);
        require(p.finalized && p.passed, "not approved");
        require(!p.executed, "executed");
        p.executed = true;
        emit ProposalExecuted(id);
    }

    function isExecutable(uint256 id) external view override returns (bool) {
        Proposal storage p = _proposal(id);
        return p.finalized && p.passed && !p.executed;
    }

    function getApprovedPayout(uint256 id)
        external
        view
        override
        returns (address token_, address payable to, uint256 amount)
    {
        Proposal storage p = _proposal(id);
        require(p.finalized && p.passed, "not approved");
        token_ = p.payout.token;
        to = p.payout.to;
        amount = p.payout.amount;
    }

    function getProposal(uint256 id)
        external
        view
        returns (Proposal memory proposal_)
    {
        Proposal storage p = _proposal(id);
        proposal_ = Proposal({
            proposer: p.proposer,
            startTs: p.startTs,
            endTs: p.endTs,
            payout: p.payout,
            finalized: p.finalized,
            passed: p.passed,
            executed: p.executed,
            forVotes: p.forVotes,
            againstVotes: p.againstVotes
        });
    }

    function _proposal(uint256 id) internal view returns (Proposal storage p) {
        require(id > 0 && id <= proposalCount, "invalid id");
        p = proposals[id];
    }
}
