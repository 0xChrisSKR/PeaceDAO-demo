// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IDaoVaultERC20 {
    function receiveERC20(address token, uint256 amount) external;
}

/// @title PeaceSwapFeeCollector
/// @notice Splits swap fees between the DAO and the founder wallet, routing
/// native assets to the PeaceFund and ERC20 tokens to the DaoVaultERC20.
contract PeaceSwapFeeCollector {
    uint256 private constant MAX_BPS = 10_000;
    uint256 public constant SWAP_FEE_BPS = 50; // 0.5%
    uint256 public constant DAO_SHARE_BPS = 8_000; // 80% of the fee (0.4% overall)
    uint256 public constant FOUNDER_SHARE_BPS = 2_000; // 20% of the fee (0.1% overall)

    address public owner;
    address public daoFundNative;
    address public daoVaultERC20;
    address public founderWallet;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DaoFundNativeUpdated(address indexed daoFund);
    event DaoVaultERC20Updated(address indexed daoVault);
    event FounderWalletUpdated(address indexed founder);
    event FeeSplitNative(
        address indexed payer,
        uint256 amount,
        uint256 daoShare,
        uint256 founderShare
    );
    event FeeSplitERC20(
        address indexed token,
        address indexed payer,
        uint256 amount,
        uint256 daoShare,
        uint256 founderShare
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _daoFundNative, address _daoVaultERC20, address _founderWallet) {
        require(_daoFundNative != address(0), "fund=0");
        require(_founderWallet != address(0), "founder=0");
        owner = msg.sender;
        daoFundNative = _daoFundNative;
        daoVaultERC20 = _daoVaultERC20;
        founderWallet = _founderWallet;
        emit OwnershipTransferred(address(0), msg.sender);
        emit DaoFundNativeUpdated(_daoFundNative);
        if (_daoVaultERC20 != address(0)) {
            emit DaoVaultERC20Updated(_daoVaultERC20);
        }
        emit FounderWalletUpdated(_founderWallet);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDaoFundNative(address _daoFundNative) external onlyOwner {
        require(_daoFundNative != address(0), "fund=0");
        daoFundNative = _daoFundNative;
        emit DaoFundNativeUpdated(_daoFundNative);
    }

    function setDaoVaultERC20(address _daoVaultERC20) external onlyOwner {
        daoVaultERC20 = _daoVaultERC20;
        emit DaoVaultERC20Updated(_daoVaultERC20);
    }

    function setFounderWallet(address _founderWallet) external onlyOwner {
        require(_founderWallet != address(0), "founder=0");
        founderWallet = _founderWallet;
        emit FounderWalletUpdated(_founderWallet);
    }

    /// @notice Collects and forwards native token fees.
    function collectNativeFee() external payable {
        require(msg.value > 0, "fee=0");
        require(daoFundNative != address(0), "fund unset");
        require(founderWallet != address(0), "founder unset");

        uint256 daoShare = (msg.value * DAO_SHARE_BPS) / MAX_BPS;
        uint256 founderShare = msg.value - daoShare;

        (bool daoOk, ) = payable(daoFundNative).call{value: daoShare}("");
        require(daoOk, "dao send failed");
        (bool founderOk, ) = payable(founderWallet).call{value: founderShare}("");
        require(founderOk, "founder send failed");

        emit FeeSplitNative(msg.sender, msg.value, daoShare, founderShare);
    }

    /// @notice Collects and forwards ERC20 token fees.
    /// @param token The ERC20 token address paying the fee.
    /// @param amount The total fee amount to split.
    function collectERC20Fee(address token, uint256 amount) external {
        require(token != address(0), "token=0");
        require(amount > 0, "fee=0");
        require(founderWallet != address(0), "founder unset");
        require(daoVaultERC20 != address(0), "vault unset");

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "transferFrom fail");

        uint256 daoShare = (amount * DAO_SHARE_BPS) / MAX_BPS;
        uint256 founderShare = amount - daoShare;

        require(IERC20(token).transfer(daoVaultERC20, daoShare), "dao transfer fail");
        IDaoVaultERC20(daoVaultERC20).receiveERC20(token, daoShare);
        require(IERC20(token).transfer(founderWallet, founderShare), "founder transfer fail");

        emit FeeSplitERC20(token, msg.sender, amount, daoShare, founderShare);
    }
}
