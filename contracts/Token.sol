// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./TokenPeg.sol";

import "./Roles.sol";

uint256 constant TOTAL_SUPPLY = 1_000_000_000e6; // 1B tokens (6 decimals each)
string constant NAME = "THINK Token";
string constant SYMBOL = "THINK";

/**
 * @dev Futureverse ERC20 token
 */
contract Token is AccessControl, ReentrancyGuard, ERC20Capped, Pausable {
    bool private _initialized;
    uint256 public reimbursementFee = 10; // 10%
    uint256 public fees;
    TokenPeg public peg;

    mapping(address sender => uint256 amount) public refunds;

    event Stored(address indexed addr, uint256 amount);
    event WithdrawnForFee(address indexed addr, uint256 amount, uint256 fee);
    event AdminWithdrawal(address indexed recipient, uint256 amount);

    constructor(
        address rolesManager,
        address tokenContractManager,
        address tokenRecoveryManager,
        address multisig
    ) ERC20Capped(TOTAL_SUPPLY) ERC20(NAME, SYMBOL) {
        _grantRole(DEFAULT_ADMIN_ROLE, rolesManager);
        _grantRole(TOKEN_RECOVERY_ROLE, tokenRecoveryManager);
        _grantRole(MANAGER_ROLE, tokenContractManager);
        _grantRole(MULTISIG_ROLE, multisig);
    }

    receive() external payable {
        revert();
    }

    function init(address _peg) external onlyRole(MANAGER_ROLE) {
        require(!_initialized, "Already initialized");
        require(_peg != address(0), "Invalid peg address");

        _mint(_peg, TOTAL_SUPPLY);
        peg = TokenPeg(_peg);
        _initialized = true;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function burn(uint256 _amount) external onlyRole(MULTISIG_ROLE) {
        _burn(_msgSender(), _amount);
    }

    function mint(
        address to,
        uint256 _amount
    ) external onlyRole(MULTISIG_ROLE) {
        _mint(to, _amount);
    }

    function _beforeTokenTransfer(
        address,
        address,
        uint256
    ) internal view override {
        require(!paused(), "Token transfers are paused");
    }

    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(MULTISIG_ROLE) {
        _unpause();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (to == address(this)) {
            uint256 fee = (amount * reimbursementFee) / 100;
            uint256 refund = amount - fee;
            refunds[from] += refund;
            fees += fee;
            emit Stored(from, refund);
        }
        if (to == address(peg)) {
            peg.store(from, amount);
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
        uint256 refund = refunds[addr];
        require(refund > 0, "No refund available");
        delete refunds[addr];
        _transfer(address(this), addr, refund);
        emit WithdrawnForFee(addr, refund, reimbursementFee);
    }

    function adminFeesWithdrawal(
        address recipient
    ) external onlyRole(TOKEN_RECOVERY_ROLE) nonReentrant {
        uint256 availableFees = fees;
        require(availableFees > 0, "No fees available");
        require(recipient != address(0), "Invalid recipient address");

        fees = 0;
        _transfer(address(this), recipient, availableFees);
        emit AdminWithdrawal(recipient, availableFees);
    }
}
