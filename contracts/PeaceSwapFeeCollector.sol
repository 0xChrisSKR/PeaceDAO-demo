// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PeaceSwapFeeCollector {
    uint256 private constant FEE_DENOMINATOR = 10_000;
    uint256 private constant DAO_SHARE = 8_000;     // 80%
    uint256 private constant FOUNDER_SHARE = 2_000; // 20%

    address public dao;
    address public founder;
    address public owner;

    event RecipientsUpdated(address indexed dao, address indexed founder);
    event TokenFeeCollected(address indexed token, address indexed from, uint256 amount, uint256 daoShare, uint256 founderShare);
    event NativeFeeCollected(address indexed from, uint256 amount, uint256 daoShare, uint256 founderShare);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address dao_, address founder_) {
        require(dao_ != address(0) && founder_ != address(0), "zero address");
        dao = dao_;
        founder = founder_;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        emit RecipientsUpdated(dao_, founder_);
    }

    function setRecipients(address dao_, address founder_) external onlyOwner {
        require(dao_ != address(0) && founder_ != address(0), "zero address");
        dao = dao_;
        founder = founder_;
        emit RecipientsUpdated(dao_, founder_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function depositToken(address token, uint256 amount) external {
        require(amount > 0, "amount=0");
        require(IERC20Minimal(token).transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        uint256 founderAmount = (amount * FOUNDER_SHARE) / FEE_DENOMINATOR;
        uint256 daoAmount = amount - founderAmount;

        require(IERC20Minimal(token).transfer(dao, daoAmount), "dao transfer failed");
        require(IERC20Minimal(token).transfer(founder, founderAmount), "founder transfer failed");

        emit TokenFeeCollected(token, msg.sender, amount, daoAmount, founderAmount);
    }

    function depositNative() external payable {
        require(msg.value > 0, "amount=0");

        uint256 founderAmount = (msg.value * FOUNDER_SHARE) / FEE_DENOMINATOR;
        uint256 daoAmount = msg.value - founderAmount;

        (bool daoSuccess, ) = dao.call{value: daoAmount}("");
        require(daoSuccess, "dao transfer failed");

        (bool founderSuccess, ) = founder.call{value: founderAmount}("");
        require(founderSuccess, "founder transfer failed");

        emit NativeFeeCollected(msg.sender, msg.value, daoAmount, founderAmount);
    }
}
