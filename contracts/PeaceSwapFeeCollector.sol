// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title PeaceSwapFeeCollector (stub)
/// @notice Placeholder contract for routing swap fees between DAO treasury and founder wallet.
contract PeaceSwapFeeCollector {
    address public immutable daoFund;
    address public immutable founder;
    uint16 public immutable daoShareBps;
    uint16 public immutable founderShareBps;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    event FeeSplit(address indexed token, uint256 amount, uint256 daoAmount, uint256 founderAmount);

    constructor(address daoFund_, address founder_, uint16 daoShareBps_, uint16 founderShareBps_) {
        require(daoFund_ != address(0), "daoFund=0");
        require(founder_ != address(0), "founder=0");
        require(daoShareBps_ + founderShareBps_ == BPS_DENOMINATOR, "shares!=100%");
        daoFund = daoFund_;
        founder = founder_;
        daoShareBps = daoShareBps_;
        founderShareBps = founderShareBps_;
    }

    /// @notice Placeholder fee splitter — emits event only (logic added in later revisions).
    function splitFee(address token, uint256 amount) external {
        require(token != address(0), "token=0");
        require(amount > 0, "amount=0");
        uint256 daoAmount = (amount * daoShareBps) / BPS_DENOMINATOR;
        uint256 founderAmount = amount - daoAmount;
        emit FeeSplit(token, amount, daoAmount, founderAmount);
    }
}
