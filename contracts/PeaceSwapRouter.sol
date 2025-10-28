// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeCollector {
    function splitFee(address token, uint256 amount) external returns (uint256 daoAmount, uint256 founderAmount);
}

/// @title PeaceSwapRouter
/// @notice Minimal placeholder router that will wrap an underlying DEX router with fee logic.
contract PeaceSwapRouter {
    address public immutable underlyingRouter;
    IFeeCollector public immutable feeCollector;
    uint256 public immutable feeBps;

    event SwapWithFee(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOutMin, address to);

    constructor(address underlyingRouter_, address feeCollector_, uint256 feeBps_) {
        require(underlyingRouter_ != address(0), "router=0");
        require(address(feeCollector_) != address(0), "collector=0");
        require(feeBps_ <= 10_000, "fee too high");
        underlyingRouter = underlyingRouter_;
        feeCollector = IFeeCollector(feeCollector_);
        feeBps = feeBps_;
    }

    function swapExactTokensForTokensWithFee(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut) {
        emit SwapWithFee(msg.sender, tokenIn, tokenOut, amountIn, amountOutMin, to);
        return 0;
    }
}
