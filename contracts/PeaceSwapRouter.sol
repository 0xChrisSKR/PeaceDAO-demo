// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPeaceSwapFeeCollector {
    function depositToken(address token, uint256 amount) external;
    function depositNative() external payable;
}

interface IRouterLike {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function WETH() external view returns (address);
}

contract PeaceSwapRouter {
    uint256 private constant FEE_DENOMINATOR = 10_000;
    uint256 private constant FEE_BPS = 50; // 0.5%

    IRouterLike public immutable baseRouter;
    IPeaceSwapFeeCollector public immutable feeCollector;

    event SwapWithFee(address indexed sender, address indexed inputToken, uint256 amountIn, uint256 feeAmount);

    constructor(address baseRouter_, address feeCollector_) {
        require(baseRouter_ != address(0) && feeCollector_ != address(0), "zero address");
        baseRouter = IRouterLike(baseRouter_);
        feeCollector = IPeaceSwapFeeCollector(feeCollector_);
    }

    receive() external payable {}

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        _validatePath(path);
        _pullTokens(path[0], amountIn);

        (uint256 netAmount, uint256 feeAmount) = _collectTokenFee(path[0], amountIn);
        _approve(path[0], address(baseRouter), netAmount);

        amounts = baseRouter.swapExactTokensForTokens(netAmount, amountOutMin, path, to, deadline);
        emit SwapWithFee(msg.sender, path[0], amountIn, feeAmount);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        _validatePath(path);
        require(path[path.length - 1] == baseRouter.WETH(), "invalid WETH path");

        _pullTokens(path[0], amountIn);
        (uint256 netAmount, uint256 feeAmount) = _collectTokenFee(path[0], amountIn);
        _approve(path[0], address(baseRouter), netAmount);

        amounts = baseRouter.swapExactTokensForETH(netAmount, amountOutMin, path, to, deadline);
        emit SwapWithFee(msg.sender, path[0], amountIn, feeAmount);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        _validatePath(path);
        require(path[0] == baseRouter.WETH(), "invalid WETH path");
        require(msg.value > 0, "no value");

        (uint256 netAmount, uint256 feeAmount) = _collectNativeFee(msg.value);
        amounts = baseRouter.swapExactETHForTokens{value: netAmount}(amountOutMin, path, to, deadline);
        emit SwapWithFee(msg.sender, address(0), msg.value, feeAmount);
    }

    function _pullTokens(address token, uint256 amount) internal {
        require(amount > 0, "amount=0");
        require(IERC20Minimal(token).transferFrom(msg.sender, address(this), amount), "transferFrom failed");
    }

    function _collectTokenFee(address token, uint256 amount) internal returns (uint256 netAmount, uint256 feeAmount) {
        feeAmount = (amount * FEE_BPS) / FEE_DENOMINATOR;
        netAmount = amount - feeAmount;
        require(netAmount > 0, "fee exceeds amount");

        if (feeAmount > 0) {
            _approve(token, address(feeCollector), feeAmount);
            feeCollector.depositToken(token, feeAmount);
        }
    }

    function _collectNativeFee(uint256 value) internal returns (uint256 netAmount, uint256 feeAmount) {
        feeAmount = (value * FEE_BPS) / FEE_DENOMINATOR;
        netAmount = value - feeAmount;
        require(netAmount > 0, "fee exceeds amount");

        if (feeAmount > 0) {
            feeCollector.depositNative{value: feeAmount}();
        }
    }

    function _approve(address token, address spender, uint256 amount) internal {
        require(IERC20Minimal(token).approve(spender, 0), "approve reset failed");
        require(IERC20Minimal(token).approve(spender, amount), "approve failed");
    }

    function _validatePath(address[] calldata path) internal pure {
        require(path.length >= 2, "path too short");
    }

}
