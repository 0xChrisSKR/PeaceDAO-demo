// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGovernance {
    function isExecutable(uint256 proposalId) external view returns (bool);

    function getApprovedPayout(uint256 proposalId)
        external
        view
        returns (address token, address payable to, uint256 amount);
}
