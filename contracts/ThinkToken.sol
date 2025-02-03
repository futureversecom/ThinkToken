// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./TokenRecovery.sol";
import "./Roles.sol";

uint256 constant TOTAL_SUPPLY = 1_000_000_000e6; // 1B tokens (6 decimals each)
string constant NAME = "THINK Token";
string constant SYMBOL = "THINK";

/**
 * @dev Futureverse ERC20 THINK token
 */
contract ThinkToken is TokenRecovery, ERC20Capped, Pausable {
    bool private _initialized;

    constructor(
        address manager,
        address multisig
    ) ERC20Capped(TOTAL_SUPPLY) ERC20(NAME, SYMBOL) TokenRecovery(manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, manager);
        _grantRole(MANAGER_ROLE, manager);
        _grantRole(MULTISIG_ROLE, multisig);
    }

    function init(address _peg) external onlyRole(MANAGER_ROLE) {
        require(!_initialized, "Already initialized");
        require(_peg != address(0), "Invalid peg address");

        _mint(_peg, TOTAL_SUPPLY);
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
        address,
        address to,
        uint256 amount
    ) internal override {
        if (to == address(this)) _deposit(to, amount);
    }
}
