pragma solidity ^0.8.20;

// SPDX-License-Identifier: Apache-2.0

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Roles.sol";

/**
 * @dev Futureverse ERC20 THINK token
 */
contract TokenRecovery is AccessControl, ReentrancyGuard {
    uint256 internal reimbursementFee = 10; // 10%
    uint256 internal _fees;
    mapping(address sender => uint256 amount) public refunds;

    event Deposited(address indexed addr, uint256 amount);
    event WithdrawnForFee(address indexed addr, uint256 amount, uint256 fee);
    event AdminWithdrawal(address indexed recipient, uint256 amount);

    constructor(address tokenRecoveryManager) {
        _grantRole(TOKEN_RECOVERY_ROLE, tokenRecoveryManager);
    }

    receive() external payable {
        revert();
    }

    function _deposit(address to, uint256 amount) internal {
        if (to == address(this)) {
            address sender = _msgSender();
            uint256 fee = (amount * reimbursementFee) / 100;
            uint256 refund = amount - fee;
            refunds[sender] += refund;
            _fees += fee;
            emit Deposited(sender, refund);
        }
    }

    function setReimbursementFee(
        uint256 _reimbursementFee
    ) external onlyRole(TOKEN_RECOVERY_ROLE) {
        require(_reimbursementFee <= 100, "Invalid fee percentage");
        reimbursementFee = _reimbursementFee;
    }

    function withdraw() external nonReentrant {
        address addr = _msgSender();
        uint256 deposit = refunds[addr];
        if (deposit > 0) {
            delete refunds[addr];
            require(
                IERC20(address(this)).transfer(addr, deposit),
                "ERC20 transfer failed"
            );
            emit WithdrawnForFee(addr, deposit, reimbursementFee);
        }
    }

    /// Only fees can be withdrawn by the admin
    /// Users can withdraw their refunds by themselves only
    function adminFeesWithdrawal(
        address recipient
    ) external onlyRole(TOKEN_RECOVERY_ROLE) nonReentrant {
        uint256 availableFees = _fees;
        require(availableFees > 0, "No fees available");
        require(recipient != address(0), "Invalid recipient address");

        _fees = 0;
        require(
            IERC20(address(this)).transfer(recipient, availableFees),
            "ERC20 transfer failed"
        );
        emit AdminWithdrawal(recipient, availableFees);
    }

    function getReimbursementFee() external view returns (uint256) {
        return reimbursementFee;
    }

    function getFees() external view returns (uint256) {
        return _fees;
    }
}
