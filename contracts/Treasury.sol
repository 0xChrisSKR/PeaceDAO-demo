// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Treasury
 * @notice Handles DAO treasury funds. Only the governance contract
 *         can trigger fund transfers through proposals.
 */

import {IGovernance} from "./interfaces/IGovernance.sol";

/**
 * @dev Extends governance functionality with an executable proposal hook.
 */
interface IGovernanceExecutable is IGovernance {
    function executeProposal(uint256 proposalId) external;
}

contract Treasury {
    address public governance;
    mapping(address => uint256) public balances;

    event FundsReceived(address indexed from, uint256 amount);
    event FundsSent(address indexed to, uint256 amount);
    event GovernanceUpdated(address indexed oldGov, address indexed newGov);

    modifier onlyGovernance() {
        require(msg.sender == governance, "Not governance");
        _;
    }

    constructor(address _governance) {
        require(_governance != address(0), "Invalid governance");
        governance = _governance;
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function sendFunds(address payable _to, uint256 _amount) external onlyGovernance {
        require(address(this).balance >= _amount, "Insufficient funds");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
        emit FundsSent(_to, _amount);
    }

    function updateGovernance(address _newGovernance) external onlyGovernance {
        require(_newGovernance != address(0), "Invalid address");
        emit GovernanceUpdated(governance, _newGovernance);
        governance = _newGovernance;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
