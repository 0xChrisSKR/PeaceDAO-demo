// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Meta {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IGate {
    function hasVote(address) external view returns (bool);
    function hasProp(address) external view returns (bool);
}

interface IFund {
    function transferNative(address to, uint256 amount, uint256 proposalId) external;
    function executeApprovedDonation(address beneficiary, uint256 donationAmount, address verifier, uint256 proposalId) external;
    function setActiveManagers(address[] calldata managers) external;
    function maxManagers() external view returns (uint256);
}

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed from, address indexed to);
    constructor() { owner = msg.sender; }
    modifier onlyOwner() { require(msg.sender == owner, "not owner"); _; }
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        emit OwnershipTransferred(owner, newOwner); owner = newOwner;
    }
}

/**
 * 改版說明：
 * - 提案需「100 萬級身分」+ 質押 100 萬（投票結束後不論通過與否，一律退還）
 * - 投票身分門檻仍為 20 萬（由 Gate 控制）
 * - 通過後由 PeaceFund 撥出「BNB」到目的地（金庫只處理原生幣）
 */
contract PeaceDAO is Ownable {
    IERC20Meta public immutable token;
    IGate     public immutable gate;
    IFund     public immutable fund;
    uint8     public immutable tokenDecimals;

    uint256 public stakeAmount;       // 質押數量（最小單位，= 1,000,000 * 10**decimals）
    uint256 public votingDelay  = 1;
    uint256 public votingPeriod = 43_200;  // ~1 day on 3s blocks
    uint256 public quorum;                // 同意票門檻（最小單位）

    uint256 public managerStakeRequired;  // 社群經理質押門檻（500,000 代幣）
    uint256 public maxManagers;           // 可同時啟用的社群經理數量

    address public verifierContract;      // PeaceVerify 合約地址

    struct Proposal {
        address proposer;
        string  title;
        string  reason;
        address destination;
        uint256 nativeAmount;   // 撥款 BNB/ETH，單位 wei（這裡是 BNB）
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool    executed;
        bool    stakeRefunded;  // 已退還質押
        mapping(address => bool) hasVoted;
    }

    struct ManagerInfo {
        uint256 stakeAmount;
        uint64  termEnd;
        bool    active;
        bool    stakeClaimed;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) private _props;

    address[] private _activeManagers;
    mapping(address => bool) public isManager;
    mapping(address => ManagerInfo) public managerInfo;

    mapping(uint256 => address) public proposalVerifiers;

    event ParamsUpdated(uint256 stakeAmount, uint256 votingDelay, uint256 votingPeriod, uint256 quorum);
    event ProposalCreated(uint256 indexed id, address indexed proposer, string title, address destination, uint256 nativeAmount,
 uint256 startBlock, uint256 endBlock);
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id, bool passed);
    event StakeRefunded(uint256 indexed id, address indexed proposer, uint256 amount);
    event ManagersAppointed(address[] managers, uint256 termEnd);
    event ManagersRemoved(address[] managers);
    event ManagerStakeClaimed(address indexed manager, uint256 amount);
    event MaxManagersUpdated(uint256 newMax);
    event VerifierContractUpdated(address indexed verifierContract);
    event VerifierRecorded(uint256 indexed proposalId, address indexed verifier);

    constructor(address token_, address gate_, address fund_) {
        require(token_ != address(0) && gate_ != address(0) && fund_ != address(0), "zero");
        token = IERC20Meta(token_);
        gate  = IGate(gate_);
        fund  = IFund(fund_);
        tokenDecimals = IERC20Meta(token_).decimals();

        uint256 base = 10 ** tokenDecimals;
        stakeAmount            = 1_000_000 * base;   // ✅ 改為 100 萬
        quorum                 = 5_000_000 * base;   // 可調（示意 500 萬）
        managerStakeRequired   = 500_000 * base;
        maxManagers            = IFund(fund_).maxManagers();

        emit ParamsUpdated(stakeAmount, votingDelay, votingPeriod, quorum);
        emit MaxManagersUpdated(maxManagers);
    }

    function setParams(uint256 _stake, uint256 _delay, uint256 _period, uint256 _quorum) external onlyOwner {
        require(_period > 0, "period=0");
        stakeAmount  = _stake;
        votingDelay  = _delay;
        votingPeriod = _period;
        quorum       = _quorum;
        emit ParamsUpdated(_stake, _delay, _period, _quorum);
    }

    function setMaxManagers(uint256 newMax) external onlyOwner {
        require(newMax > 0, "max=0");
        require(newMax >= _activeManagers.length, "lt active");
        require(newMax <= fund.maxManagers(), "gt fund");
        maxManagers = newMax;
        emit MaxManagersUpdated(newMax);
    }

    function setVerifierContract(address verifier_) external onlyOwner {
        require(verifier_ != address(0), "verifier=0");
        verifierContract = verifier_;
        emit VerifierContractUpdated(verifier_);
    }

    function getProposal(uint256 id) external view returns (
        address proposer, string memory title, string memory reason,
        address destination, uint256 nativeAmount,
        uint256 startBlock, uint256 endBlock,
        uint256 forVotes, uint256 againstVotes, bool executed, bool stakeRefunded
    ) {
        Proposal storage p = _props[id];
        return (p.proposer, p.title, p.reason, p.destination, p.nativeAmount,
                p.startBlock, p.endBlock, p.forVotes, p.againstVotes, p.executed, p.stakeRefunded);
    }

    function getActiveManagers() external view returns (address[] memory) {
        return _activeManagers;
    }

    function propose(
        string calldata title,
        string calldata reason,
        address destination,
        uint256 nativeAmount
    ) external returns (uint256 id) {
        require(gate.hasProp(msg.sender), "no proposer role");
        require(destination != address(0), "dest=0");

        // ✅ 建立提案同時質押 100 萬（前端需先 approve）
        require(token.transferFrom(msg.sender, address(this), stakeAmount), "stake fail");

        id = ++proposalCount;
        Proposal storage p = _props[id];
        p.proposer     = msg.sender;
        p.title        = title;
        p.reason       = reason;
        p.destination  = destination;
        p.nativeAmount = nativeAmount;
        p.startBlock   = block.number + votingDelay;
        p.endBlock     = p.startBlock + votingPeriod;

        emit ProposalCreated(id, msg.sender, title, destination, nativeAmount, p.startBlock, p.endBlock);
    }

    function _weight(address voter) internal view returns (uint256) {
        return token.balanceOf(voter);
    }

    function castVote(uint256 id, bool support) external {
        Proposal storage p = _props[id];
        require(block.number >= p.startBlock && block.number <= p.endBlock, "closed");
        require(gate.hasVote(msg.sender), "no voter role");
        require(!p.hasVoted[msg.sender], "voted");

        uint256 w = _weight(msg.sender);
        require(w > 0, "zero weight");

        p.hasVoted[msg.sender] = true;
        if (support) p.forVotes += w; else p.againstVotes += w;
        emit VoteCast(id, msg.sender, support, w);
    }

    function execute(uint256 id) external {
        Proposal storage p = _props[id];
        require(block.number > p.endBlock,        "not ended");
        require(!p.executed,                      "executed");

        bool passed = (p.forVotes >= quorum) && (p.forVotes > p.againstVotes);
        p.executed = true;
        emit ProposalExecuted(id, passed);

        address verifierForProposal = proposalVerifiers[id];

        // ✅ 提案通過才由金庫撥「BNB」；不通過則不撥款
        if (passed && p.nativeAmount > 0) {
            require(verifierForProposal != address(0), "verifier missing");
            fund.executeApprovedDonation(p.destination, p.nativeAmount, verifierForProposal, id);
        }

        delete proposalVerifiers[id];

        // ✅ 無論通過/否決，一律退還質押
        if (!p.stakeRefunded) {
            p.stakeRefunded = true;
            require(token.transfer(p.proposer, stakeAmount), "refund fail");
            emit StakeRefunded(id, p.proposer, stakeAmount);
        }
    }

    function appointManagers(address[] calldata newManagers, uint64 termEnd) external onlyOwner {
        require(newManagers.length > 0, "no managers");
        require(termEnd > block.timestamp, "term");
        require(_activeManagers.length + newManagers.length <= maxManagers, "max exceeded");

        for (uint256 i = 0; i < newManagers.length; i++) {
            address manager = newManagers[i];
            require(manager != address(0), "manager=0");
            require(!isManager[manager], "duplicate");
            require(token.balanceOf(manager) >= managerStakeRequired, "bal<stake");
            require(token.transferFrom(manager, address(this), managerStakeRequired), "stake fail");

            managerInfo[manager] = ManagerInfo({
                stakeAmount: managerStakeRequired,
                termEnd: termEnd,
                active: true,
                stakeClaimed: false
            });
            isManager[manager] = true;
            _activeManagers.push(manager);
        }

        fund.setActiveManagers(_activeManagers);
        emit ManagersAppointed(newManagers, termEnd);
    }

    function removeManagers(address[] calldata removeList) external onlyOwner {
        require(removeList.length > 0, "no managers");

        for (uint256 i = 0; i < removeList.length; i++) {
            address manager = removeList[i];
            require(isManager[manager], "not manager");

            _removeActiveManager(manager);
            isManager[manager] = false;

            ManagerInfo storage info = managerInfo[manager];
            info.active = false;

            if (block.timestamp >= info.termEnd && !info.stakeClaimed && info.stakeAmount > 0) {
                _releaseStake(manager, info);
            }
        }

        fund.setActiveManagers(_activeManagers);
        emit ManagersRemoved(removeList);
    }

    function claimManagerStake() external {
        ManagerInfo storage info = managerInfo[msg.sender];
        require(info.stakeAmount > 0, "no stake");
        require(!info.active, "still active");
        require(block.timestamp >= info.termEnd, "term");
        require(!info.stakeClaimed, "claimed");

        _releaseStake(msg.sender, info);
    }

    function recordDonationVerifier(uint256 proposalId, address verifier) external {
        require(msg.sender == verifierContract, "not verifier");
        require(verifier != address(0), "verifier=0");

        Proposal storage p = _props[proposalId];
        require(p.proposer != address(0), "invalid id");
        require(!p.executed, "executed");

        proposalVerifiers[proposalId] = verifier;
        emit VerifierRecorded(proposalId, verifier);
    }

    function _removeActiveManager(address manager) internal {
        uint256 len = _activeManagers.length;
        for (uint256 i = 0; i < len; i++) {
            if (_activeManagers[i] == manager) {
                _activeManagers[i] = _activeManagers[len - 1];
                _activeManagers.pop();
                break;
            }
        }
    }

    function _releaseStake(address manager, ManagerInfo storage info) internal {
        uint256 amount = info.stakeAmount;
        info.stakeAmount = 0;
        info.stakeClaimed = true;
        require(token.transfer(manager, amount), "stake return fail");
        emit ManagerStakeClaimed(manager, amount);
    }
}
