// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title DaoVaultERC20 - DAO vault for ERC20 fees
/// @notice Receives ERC20 fees routed by the PeaceSwap fee collector and
/// allows the DAO to forward tokens when instructed.
contract DaoVaultERC20 {
    address public owner;
    address public dao;
    address public feeCollector;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DaoUpdated(address indexed dao);
    event FeeCollectorUpdated(address indexed collector);
    event ERC20Received(address indexed token, address indexed from, uint256 amount);
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyOwnerOrDao() {
        require(msg.sender == owner || msg.sender == dao, "not auth");
        _;
    }

    modifier onlyFeeCollector() {
        require(msg.sender == feeCollector, "not collector");
        _;
    }

    constructor(address _dao, address _feeCollector) {
        require(_dao != address(0), "dao=0");
        owner = msg.sender;
        dao = _dao;
        feeCollector = _feeCollector;
        emit OwnershipTransferred(address(0), msg.sender);
        emit DaoUpdated(_dao);
        if (_feeCollector != address(0)) {
            emit FeeCollectorUpdated(_feeCollector);
        }
    }

    /// @notice Transfers ownership to a new address (e.g. DAO executor).
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner=0");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Allows the owner to update the DAO controlling address.
    function setDao(address _dao) external onlyOwner {
        require(_dao != address(0), "dao=0");
        dao = _dao;
        emit DaoUpdated(_dao);
    }

    /// @notice Allows the owner to set or update the authorised fee collector.
    function setFeeCollector(address _collector) external onlyOwner {
        feeCollector = _collector;
        emit FeeCollectorUpdated(_collector);
    }

    /// @notice Records ERC20 fees forwarded from the fee collector.
    /// @dev Tokens should already have been transferred to this vault before calling.
    function receiveERC20(address token, uint256 amount) external onlyFeeCollector {
        require(token != address(0), "token=0");
        require(amount > 0, "amount=0");
        require(IERC20(token).balanceOf(address(this)) >= amount, "insufficient");
        emit ERC20Received(token, msg.sender, amount);
    }

    /// @notice Forwards ERC20 tokens under DAO or owner instruction.
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwnerOrDao {
        require(token != address(0), "token=0");
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");
        require(IERC20(token).transfer(to, amount), "transfer failed");
        emit ERC20Withdrawn(token, to, amount);
    }
}
