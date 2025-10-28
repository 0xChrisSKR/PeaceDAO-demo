// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PeaceSwapFeeCollector {
    address public owner;
    address public daoTreasury;
    address public founderWallet;

    uint16 public immutable daoShareBps;
    uint16 public immutable founderShareBps;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DaoTreasuryUpdated(address indexed newTreasury);
    event FounderWalletUpdated(address indexed newFounderWallet);
    event TokenFeeCollected(address indexed token, uint256 totalAmount, uint256 daoAmount, uint256 founderAmount);
    event NativeFeeCollected(address indexed payer, uint256 totalAmount, uint256 daoAmount, uint256 founderAmount);

    error InvalidAddress();
    error InvalidBps();

    constructor(
        address daoTreasury_,
        address founderWallet_,
        uint16 daoShareBps_,
        uint16 founderShareBps_
    ) {
        if (daoTreasury_ == address(0) || founderWallet_ == address(0)) revert InvalidAddress();
        if (daoShareBps_ + founderShareBps_ != 10_000) revert InvalidBps();

        owner = msg.sender;
        daoTreasury = daoTreasury_;
        founderWallet = founderWallet_;
        daoShareBps = daoShareBps_;
        founderShareBps = founderShareBps_;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyNonZero(address account) {
        if (account == address(0)) revert InvalidAddress();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner onlyNonZero(newOwner) {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDaoTreasury(address newTreasury) external onlyOwner onlyNonZero(newTreasury) {
        daoTreasury = newTreasury;
        emit DaoTreasuryUpdated(newTreasury);
    }

    function setFounderWallet(address newFounderWallet) external onlyOwner onlyNonZero(newFounderWallet) {
        founderWallet = newFounderWallet;
        emit FounderWalletUpdated(newFounderWallet);
    }

    function collectTokenFee(address token, uint256 amount) external {
        if (amount == 0) return;

        require(IERC20Minimal(token).transferFrom(msg.sender, address(this), amount), "collect fail");

        uint256 daoAmount = (amount * daoShareBps) / 10_000;
        uint256 founderAmount = amount - daoAmount;

        if (daoAmount > 0) {
            require(IERC20Minimal(token).transfer(daoTreasury, daoAmount), "dao transfer fail");
        }
        if (founderAmount > 0) {
            require(IERC20Minimal(token).transfer(founderWallet, founderAmount), "founder transfer fail");
        }

        emit TokenFeeCollected(token, amount, daoAmount, founderAmount);
    }

    function collectNativeFee() external payable {
        if (msg.value == 0) return;

        uint256 daoAmount = (msg.value * daoShareBps) / 10_000;
        uint256 founderAmount = msg.value - daoAmount;

        (bool okDao, ) = payable(daoTreasury).call{value: daoAmount}("");
        require(okDao, "dao native fail");

        (bool okFounder, ) = payable(founderWallet).call{value: founderAmount}("");
        require(okFounder, "founder native fail");

        emit NativeFeeCollected(msg.sender, msg.value, daoAmount, founderAmount);
    }
}
