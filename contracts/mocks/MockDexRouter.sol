// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20MockLike {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MockDexRouter {
    event SwapExecuted(address indexed sender, address[] path, uint256 amountIn, uint256 amountOut);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "path");
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        require(IERC20MockLike(tokenIn).transferFrom(msg.sender, address(this), amountIn), "pull fail");
        require(IERC20MockLike(tokenOut).transfer(to, amountIn), "push fail");

        amounts = new uint256[](path.length);
        for (uint256 i = 0; i < path.length; i++) {
            amounts[i] = amountIn;
        }

        emit SwapExecuted(msg.sender, path, amountIn, amountIn);
    }
}
