// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

uint128 constant TOTAL_SUPPLY = 1_000_000_000e6; // 1B tokens (6 decimals each)
string constant NAME = "THINK Token";
string constant SYMBOL = "THINK";
bytes32 constant MANAGER = keccak256("MANAGER");
bytes32 constant MULTISIG = keccak256("MULTISIG");

/**
 * @dev Futureverse ERC20 THINK token
 */
contract ThinkToken is ERC20Capped, Pausable, AccessControl {
    bool private _initialized;
    uint256 internal reimbursmentFee;
    uint256 internal _fees;
    mapping(address sender => uint256 amount) public deposits;

    event Deposited(address indexed addr, uint256 amount);
    event WithdrawnForFee(address indexed addr, uint256 amount, uint256 fee);
    event DepositTooSmall(address indexed addr, uint256 amount);
    event AdminWithdrawal(address indexed recipient, uint256 amount);

    constructor(
        address manager,
        address multisig
    ) ERC20Capped(TOTAL_SUPPLY) ERC20(NAME, SYMBOL) {
        _grantRole(MANAGER, manager);
        _grantRole(MULTISIG, multisig);
    }

    function init(
        address _peg,
        uint256 _reimbursmentFee
    ) external onlyRole(MANAGER) {
        require(!_initialized, "Already initialized");

        _mint(_peg, TOTAL_SUPPLY);
        reimbursmentFee = _reimbursmentFee;
        _initialized = true;
    }

    receive() external payable {
        revert();
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function burn(uint128 _amount) external onlyRole(MULTISIG) {
        _burn(_msgSender(), _amount);
    }

    function mint(address to, uint128 _amount) external onlyRole(MULTISIG) {
        _mint(to, _amount);
    }

    function _beforeTokenTransfer(
        address,
        address,
        uint256
    ) internal view override {
        require(!paused(), "Token transfers are paused");
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (to == address(this)) {
            deposits[from] = amount;
        }
    }

    function pause() external onlyRole(MANAGER) {
        _pause();
    }

    function unpause() external onlyRole(MULTISIG) {
        _unpause();
    }

    function addManager(address addr) external onlyRole(MANAGER) {
        _grantRole(MANAGER, addr);
    }

    function removeManager(address addr) external onlyRole(MANAGER) {
        _revokeRole(MANAGER, addr);
    }

    function setReimbursmentFee(
        uint256 _reimbursmentFee
    ) external onlyRole(MANAGER) {
        reimbursmentFee = _reimbursmentFee;
    }

    function withdraw() external {
        address addr = _msgSender();
        uint256 deposit = deposits[addr];

        if (deposit > reimbursmentFee) {
            uint256 amount = deposit - reimbursmentFee;
            delete deposits[addr];
            _fees += reimbursmentFee;
            _transfer(address(this), addr, amount);
            emit WithdrawnForFee(addr, amount, reimbursmentFee);
        } else {
            emit DepositTooSmall(addr, deposit);
        }
    }

    function adminWithdrawal(
        address recipient,
        uint256 amount
    ) external onlyRole(MANAGER) {
        uint256 balance = balanceOf(address(this));
        uint256 withdrawAmount = amount > 0 ? amount : _fees;

        require(withdrawAmount <= balance, "Insufficient balance");
        require(recipient != address(0), "Invalid recipient address");

        _fees = amount > 0 ? _fees - amount : 0;

        _transfer(address(this), recipient, withdrawAmount);
        emit AdminWithdrawal(recipient, withdrawAmount);
    }
}
