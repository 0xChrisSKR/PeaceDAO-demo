// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PeaceFund - BNB 公益金庫
/// @notice 收取 BNB 捐款、由 DAO 指令撥款，所有轉帳公開透明
contract PeaceFund {
    address public dao;        // DAO 合約地址
    address public owner;      // 暫時擁有者（部署人，可移轉）

    event Received(address indexed from, uint256 amount);
    event Sent(address indexed to, uint256 amount, uint256 proposalId);
    event DaoSet(address indexed dao);
    event OwnershipTransferred(address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyDAO() {
        require(msg.sender == dao, "not dao");
        _;
    }

    constructor() {
        owner = msg.sender;
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

    // DAO 合約可從此金庫撥款
    function transferNative(address to, uint256 amount, uint256 proposalId) external onlyDAO {
        require(address(this).balance >= amount, "insufficient");
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "send failed");
        emit Sent(to, amount, proposalId);
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
}
