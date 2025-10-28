// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Permitless {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPeaceSwapFeeCollector {
    function collectTokenFee(address token, uint256 amount) external;
}

interface IUnderlyingRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract PeaceSwapRouter {
    address private immutable _underlyingRouter;
    address private immutable _feeCollector;
    uint16 private immutable _feeBps;

    event SwapWithFee(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 feeAmount,
        uint256 amountOut
    );

    error InvalidPath();
    error DeadlineExpired();

    constructor(address underlyingRouter_, address feeCollector_, uint16 feeBps_) {
        require(underlyingRouter_ != address(0) && feeCollector_ != address(0), "zero");
        _underlyingRouter = underlyingRouter_;
        _feeCollector = feeCollector_;
        _feeBps = feeBps_;
    }

    function underlyingRouter() external view returns (address) {
        return _underlyingRouter;
    }

    function feeCollector() external view returns (address) {
        return _feeCollector;
    }

    function feeBps() external view returns (uint16) {
        return _feeBps;
    }

    function swapExactTokensForTokensWithFee(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();
        if (deadline < block.timestamp) revert DeadlineExpired();

        address inputToken = path[0];
        require(IERC20Permitless(inputToken).transferFrom(msg.sender, address(this), amountIn), "transfer in fail");

        uint256 feeAmount = (amountIn * _feeBps) / 10_000;
        uint256 amountAfterFee = amountIn - feeAmount;

        if (feeAmount > 0) {
            require(IERC20Permitless(inputToken).approve(_feeCollector, 0), "fee approve reset fail");
            require(IERC20Permitless(inputToken).approve(_feeCollector, feeAmount), "fee approve fail");
            IPeaceSwapFeeCollector(_feeCollector).collectTokenFee(inputToken, feeAmount);
        }

        require(amountAfterFee > 0, "amountAfterFee=0");
        require(IERC20Permitless(inputToken).approve(_underlyingRouter, 0), "dex approve reset fail");
        require(IERC20Permitless(inputToken).approve(_underlyingRouter, amountAfterFee), "dex approve fail");

        amounts = IUnderlyingRouter(_underlyingRouter).swapExactTokensForTokens(
            amountAfterFee,
            amountOutMin,
            path,
            to,
            deadline
        );

        uint256 amountOut = amounts[amounts.length - 1];
        emit SwapWithFee(msg.sender, path[0], path[path.length - 1], amountIn, feeAmount, amountOut);
    }
}
