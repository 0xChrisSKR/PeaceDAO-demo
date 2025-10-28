// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title PeaceSwapFeeCollector
/// @notice Placeholder fee collector that splits swap fees between DAO treasury and founder wallet.
contract PeaceSwapFeeCollector {
    address public immutable daoFund;
    address public immutable founder;
    uint256 public immutable daoShareBps;
    uint256 public immutable founderShareBps;
    address public router;

    event RouterUpdated(address indexed router);
    event FeeSplit(address indexed token, uint256 amount, uint256 daoAmount, uint256 founderAmount);

    error InvalidAddress();
    error InvalidBps();
    error NotRouter();
    error TransferFailed();

    constructor(address daoFund_, address founder_, uint256 daoShareBps_, uint256 founderShareBps_) {
        if (daoFund_ == address(0) || founder_ == address(0)) revert InvalidAddress();
        if (daoShareBps_ + founderShareBps_ != 10_000) revert InvalidBps();
        daoFund = daoFund_;
        founder = founder_;
        daoShareBps = daoShareBps_;
        founderShareBps = founderShareBps_;
        router = msg.sender;
        emit RouterUpdated(msg.sender);
    }

    modifier onlyRouter() {
        if (msg.sender != router) revert NotRouter();
        _;
    }

    function setRouter(address newRouter) external onlyRouter {
        if (newRouter == address(0)) revert InvalidAddress();
        router = newRouter;
        emit RouterUpdated(newRouter);
    }

    function splitFee(address token, uint256 amount) external onlyRouter returns (uint256 daoAmount, uint256 founderAmount) {
        if (amount == 0) {
            return (0, 0);
        }
        daoAmount = (amount * daoShareBps) / 10_000;
        founderAmount = amount - daoAmount;
        if (!IERC20Minimal(token).transfer(daoFund, daoAmount)) {
            revert TransferFailed();
        }
        if (!IERC20Minimal(token).transfer(founder, founderAmount)) {
            revert TransferFailed();
        }
        emit FeeSplit(token, amount, daoAmount, founderAmount);
    }
}
