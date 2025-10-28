// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PeaceFund - BNB 公益金庫
/// @notice 收取 BNB 捐款、由 DAO 指令撥款，所有轉帳公開透明
contract PeaceFund {
    address public dao;        // DAO 合約地址
    address public owner;      // 暫時擁有者（部署人，可移轉）
    address public founder;    // 運營剩餘款項接收者

    uint256 public immutable opsKeepBps;   // 捐款金額的多少保留給運營（預設 10%）
    uint256 public immutable rewardPpm;    // 驗證者 / 社群經理獎勵的百萬分比（預設 0.005%）
    uint256 public immutable maxManagers;  // 同時啟用的最大經理人數（預設 3 位）

    address[] private activeManagers;

    event Received(address indexed from, uint256 amount);
    event Sent(address indexed to, uint256 amount, uint256 proposalId);
    event DaoSet(address indexed dao);
    event OwnershipTransferred(address indexed from, address indexed to);
    event FounderUpdated(address indexed previousFounder, address indexed newFounder);
    event ManagersSynced(address[] managers);
    event DonationExecuted(
        address indexed beneficiary,
        uint256 donationAmount,
        uint256 beneficiaryAmount,
        uint256 opsAmount,
        uint256 verifierReward,
        uint256 managersReward
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyDAO() {
        require(msg.sender == dao, "not dao");
        _;
    }

    constructor(
        address founder_,
        uint256 opsKeepBps_,
        uint256 rewardPpm_,
        uint256 maxManagers_
    ) {
        owner = msg.sender;
        founder = founder_ == address(0) ? msg.sender : founder_;
        opsKeepBps = opsKeepBps_ == 0 ? 1_000 : opsKeepBps_; // 10%
        rewardPpm = rewardPpm_ == 0 ? 50 : rewardPpm_;       // 0.005%
        maxManagers = maxManagers_ == 0 ? 3 : maxManagers_;

        require(opsKeepBps <= 10_000, "ops bps too high");
        require(maxManagers > 0, "maxManagers=0");
    }

    // 接收捐款（BNB）
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // 額外手動捐款（呼叫 donate()）
    function donate() external payable {
        emit Received(msg.sender, msg.value);
    }

    // 設定 DAO 地址
    function setDAO(address _dao) external onlyOwner {
        require(_dao != address(0), "dao=0");
        dao = _dao;
        emit DaoSet(_dao);
    }

    // 更新 founder / operations 受益人
    function setFounder(address newFounder) external onlyOwner {
        require(newFounder != address(0), "founder=0");
        emit FounderUpdated(founder, newFounder);
        founder = newFounder;
    }

    // 由 DAO 同步啟用中的社群經理列表
    function setActiveManagers(address[] calldata managers) external onlyDAO {
        require(managers.length <= maxManagers, "too many managers");
        delete activeManagers;
        for (uint256 i = 0; i < managers.length; i++) {
            address manager = managers[i];
            require(manager != address(0), "manager=0");
            activeManagers.push(manager);
        }
        emit ManagersSynced(managers);
    }

    function getActiveManagers() public view returns (address[] memory) {
        return activeManagers;
    }

    // DAO 合約可從此金庫撥款（舊版介面，保留相容性）
    function transferNative(address to, uint256 amount, uint256 proposalId) external onlyDAO {
        require(address(this).balance >= amount, "insufficient");
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "send failed");
        emit Sent(to, amount, proposalId);
    }

    // 依照 DAO 核准的捐款執行撥款流程（含驗證者 / 社群經理獎勵）
    function executeApprovedDonation(
        address beneficiary,
        uint256 donationAmount,
        address verifier,
        uint256 proposalId
    ) external onlyDAO {
        require(beneficiary != address(0), "beneficiary=0");
        require(verifier != address(0), "verifier=0");
        require(donationAmount > 0, "amount=0");
        require(address(this).balance >= donationAmount, "insufficient");

        uint256 opsAmount = (donationAmount * opsKeepBps) / 10_000;
        uint256 beneficiaryAmount = donationAmount - opsAmount;

        uint256 verifierReward = (donationAmount * rewardPpm) / 1_000_000;

        address[] memory managers = activeManagers;
        uint256 managerCount = managers.length;
        uint256 managersRewardTarget = managerCount > 0 ? (donationAmount * rewardPpm) / 1_000_000 : 0;

        require(opsAmount >= verifierReward + managersRewardTarget, "ops<rewards");

        _transferNative(payable(beneficiary), beneficiaryAmount);

        if (verifierReward > 0) {
            _transferNative(payable(verifier), verifierReward);
        }

        uint256 distributedManagersReward = 0;
        if (managersRewardTarget > 0 && managerCount > 0) {
            uint256 share = managersRewardTarget / managerCount;
            uint256 remainder = managersRewardTarget % managerCount;
            for (uint256 i = 0; i < managerCount; i++) {
                uint256 payout = share;
                if (remainder > 0) {
                    payout += 1;
                    remainder -= 1;
                }
                if (payout > 0) {
                    _transferNative(payable(managers[i]), payout);
                    distributedManagersReward += payout;
                }
            }
        }

        uint256 opsRemainder = opsAmount - verifierReward - managersRewardTarget;
        if (opsRemainder > 0) {
            _transferNative(payable(founder), opsRemainder);
        }

        emit DonationExecuted(beneficiary, donationAmount, beneficiaryAmount, opsAmount, verifierReward, distributedManagersReward);
        emit Sent(beneficiary, beneficiaryAmount, proposalId);
    }

    // 查詢餘額（前端顯示金庫有多少 BNB）
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    // 查詢 DAO 地址（方便前端驗證）
    function daoAddress() external view returns (address) {
        return dao;
    }

    // 移轉擁有權（部署後可交給多簽或 DAO）
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _transferNative(address payable to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "send failed");
    }
}
