// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeCollector {
    function splitFee(address token, uint256 amount) external;
}

/// @title PeaceSwapRouter (stub)
/// @notice Minimal wrapper that records configuration; swap logic to be implemented later.
contract PeaceSwapRouter {
    address public immutable feeCollector;
    address public immutable underlyingRouter;
    uint16 public immutable feeBps;

    event SwapWithFee(address indexed payer, address indexed tokenIn, uint256 amountIn, uint256 feeAmount);

    constructor(address feeCollector_, address underlyingRouter_, uint16 feeBps_) {
        require(feeCollector_ != address(0), "collector=0");
        require(underlyingRouter_ != address(0), "router=0");
        require(feeBps_ <= 10_000, "fee>100%");
        feeCollector = feeCollector_;
        underlyingRouter = underlyingRouter_;
        feeBps = feeBps_;
    }

    /// @notice Placeholder swap method to keep deployment scripts functional.
    function swapExactTokensForTokensWithFee(
        address tokenIn,
        uint256 amountIn
    ) external returns (bool) {
        require(tokenIn != address(0), "tokenIn=0");
        require(amountIn > 0, "amount=0");
        uint256 feeAmount = (amountIn * feeBps) / 10_000;
        IFeeCollector(feeCollector).splitFee(tokenIn, feeAmount);
        emit SwapWithFee(msg.sender, tokenIn, amountIn, feeAmount);
        return true;
    }
}
