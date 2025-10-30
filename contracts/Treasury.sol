// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovernance} from "./interfaces/IGovernance.sol";
import {IERC20} from "./interfaces/IERC20.sol";

interface IGovernanceExecutable extends IGovernance {
    function markProposalExecuted(uint256 proposalId) external;
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Treasury is ReentrancyGuard {
    address public immutable governance;

    constructor(address _governance) {
        require(_governance != address(0), "governance=0");
        governance = _governance;
    }

    receive() external payable {}

    function executePayout(uint256 proposalId) external nonReentrant {
        IGovernanceExecutable gov = IGovernanceExecutable(governance);
        require(gov.isExecutable(proposalId), "Not executable");
        (address token, address payable to, uint256 amount) = gov.getApprovedPayout(proposalId);

        if (token == address(0)) {
            (bool ok, ) = to.call{value: amount}("");
            require(ok, "Native transfer failed");
        } else {
            require(IERC20(token).transfer(to, amount), "ERC20 transfer failed");
        }

        gov.markProposalExecuted(proposalId);
    }
}
