// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * PeaceGate + PeaceDAO (minimal)
 * 功能要點：
 * - 依 ERC20 餘額給予 3 個等級的持幣權限（僅讀、投票、可提案/委員）
 * - 簡易投票（for/against），以「目前餘額」計票；若你的代幣支援 Snapshot/Votes，可切到快照計票
 * - 事件（Events）供 Discord/Telegram Bot 監聽，自動核驗與賦權
 *
 * 重要：此為雛形。上主網前務必審計、加上防火與治理控件。
 */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

// 可選：若你的代幣支援快照（如 OpenZeppelin ERC20Snapshot）
interface IERC20Snapshot {
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
}

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed from, address indexed to);
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

    // 門檻（可調）
    uint256 public tierRead;      // >= 1 進群可讀/留言
    uint256 public tierVote;      // >= 2 可投票
    uint256 public tierPropose;   // >= 3 可提案/委員

    // 黑名單（防詐騙或違規）
    mapping(address => bool) public blacklist;

    event ThresholdsUpdated(uint256 readReq, uint256 voteReq, uint256 proposeReq);
    event BlacklistUpdated(address indexed user, bool blocked);

    constructor(address token_) {
        require(token_ != address(0), "token=0");
        token = IERC20(token_);
        // 預設門檻（請依實際代幣位數與分佈調整）
        tierRead = 1e18;       // 1 token
        tierVote = 10e18;      // 10 tokens
        tierPropose = 100e18;  // 100 tokens
    }

    function setThresholds(uint256 _read, uint256 _vote, uint256 _propose) external onlyOwner {
        require(_read <= _vote && _vote <= _propose, "tier order");
        tierRead = _read; tierVote = _vote; tierPropose = _propose;
        emit ThresholdsUpdated(_read, _vote, _propose);
    }

    function setBlacklist(address user, bool blocked) external onlyOwner {
        blacklist[user] = blocked;
        emit BlacklistUpdated(user, blocked);
    }

    enum Role { NONE, READER, VOTER, PROPOSER }

    function roleOf(address user) public view returns (Role) {
        if (blacklist[user]) return Role.NONE;
        uint256 bal = token.balanceOf(user);
        if (bal >= tierPropose) return Role.PROPOSER;
        if (bal >= tierVote)   return Role.VOTER;
        if (bal >= tierRead)   return Role.READER;
        return Role.NONE;
    }

    function hasReadAccess(address u) external view returns (bool) { return roleOf(u) >= Role.READER; }
    function hasVoteAccess(address u) external view returns (bool) { return roleOf(u) >= Role.VOTER; }
    function hasProposeAccess(address u) external view returns (bool) { return roleOf(u) >= Role.PROPOSER; }
}

contract PeaceDAO is Ownable {
    IERC20 public immutable token;
    PeaceGate public immutable gate;

    // 可選的快照來源（若你的代幣有 ERC20Snapshot）
    IERC20Snapshot public snapshotToken;
    bool public useSnapshot; // true 時用 snapshot 計票

    struct Proposal {
        address proposer;
        string  title;
        string  description;     // e.g. 修正資訊頁、社群基金用途等
        uint256 startBlock;
        uint256 endBlock;
        uint256 snapshotId;      // 若使用 snapshot，可傳對應快照 id；沒有就留 0
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public votingDelay = 1;      // 建立後延遲 1 個區塊開始
    uint256 public votingPeriod = 43_200; // 約 1 天（BSC ~3秒/塊 -> 視鏈調整）
    uint256 public quorum = 1000e18;     // 通過所需最小「同意票」總量（依代幣分佈調整）
    uint256 public proposalCount;
    mapping(uint256 => Proposal) private _proposals;

    event ProposalCreated(uint256 id, address indexed proposer, string title, uint256 startBlock, uint256 endBlock, uint256 snapshotId);
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id, bool passed);

    constructor(address token_, address gate_) {
        require(token_ != address(0) && gate_ != address(0), "zero");
        token = IERC20(token_);
        gate = PeaceGate(gate_);
    }

    // 可切換到快照模式（若你的代幣支援 ERC20Snapshot 或 Governor）
    function setSnapshotSource(address snapshotToken_, bool enabled) external onlyOwner {
        snapshotToken = IERC20Snapshot(snapshotToken_);
        useSnapshot = enabled;
    }

    function setParams(uint256 _delay, uint256 _period, uint256 _quorum) external onlyOwner {
        require(_period > 0, "period=0");
        votingDelay = _delay;
        votingPeriod = _period;
        quorum = _quorum;
    }

    function getProposal(uint256 id) external view returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 startBlock,
        uint256 endBlock,
        uint256 snapshotId,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed
    ) {
        Proposal storage p = _proposals[id];
        return (p.proposer, p.title, p.description, p.startBlock, p.endBlock, p.snapshotId, p.forVotes, p.againstVotes, p.executed);
    }

    // 只有 PROPOSER 等級才能提案
    function propose(string calldata title, string calldata description, uint256 snapshotId) external returns (uint256 id) {
        require(gate.hasProposeAccess(msg.sender), "no proposer role");

        id = ++proposalCount;
        Proposal storage p = _proposals[id];
        p.proposer = msg.sender;
        p.title = title;
        p.description = description;
        p.startBlock = block.number + votingDelay;
        p.endBlock   = p.startBlock + votingPeriod;
        p.snapshotId = snapshotId;

        emit ProposalCreated(id, msg.sender, title, p.startBlock, p.endBlock, snapshotId);
    }

    // 依目前餘額或快照餘額計票
    function _votingWeight(address voter, uint256 snapshotId) internal view returns (uint256) {
        // 快照優先（建議使用，避免投票期間轉移代幣操弄權重）
        if (useSnapshot && address(snapshotToken) != address(0) && snapshotId != 0) {
            try snapshotToken.balanceOfAt(voter, snapshotId) returns (uint256 snapBal) {
                return snapBal;
            } catch {
                // fallback 到即時餘額
            }
        }
        return token.balanceOf(voter);
    }

    function castVote(uint256 id, bool support) external {
        Proposal storage p = _proposals[id];
        require(block.number >= p.startBlock && block.number <= p.endBlock, "voting closed");
        require(gate.hasVoteAccess(msg.sender), "no voter role");
        require(!p.hasVoted[msg.sender], "voted");

        uint256 weight = _votingWeight(msg.sender, p.snapshotId);
        require(weight > 0, "zero weight");

        p.hasVoted[msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit VoteCast(id, msg.sender, support, weight);
    }

    function execute(uint256 id) external {
        Proposal storage p = _proposals[id];
        require(block.number > p.endBlock, "voting not ended");
        require(!p.executed, "executed");
        bool passed = (p.forVotes >= quorum) && (p.forVotes > p.againstVotes);
        p.executed = true;
        emit ProposalExecuted(id, passed);

        // 雛形：僅記錄通過與否＋事件
        // 實際專案可在此觸發金庫撥款、合約參數調整等「可執行動作」(Timelock + call)
    }
}
