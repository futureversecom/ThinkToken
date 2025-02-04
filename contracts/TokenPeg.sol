// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IBridge.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Roles.sol";

/// @title ERC20 Peg contract on ethereum
/// @author Root Network
/// @notice Provides an Eth/ERC20/GA Root network peg
///  - depositing: lock Eth/ERC20 tokens to redeem Root network "generic asset" (GA) 1:1
///  - withdrawing: burn or lock GAs to redeem Eth/ERC20 tokens 1:1
contract TokenPeg is AccessControl, IBridgeReceiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token; // token isn't updatable

    // whether the peg is accepting deposits
    bool public depositsActive;
    // whether the peg is accepting withdrawals
    bool public withdrawalsActive;
    //  Bridge contract address
    IBridge public bridge;
    // the (pseudo) pallet address this contract is paired with on root
    address public palletAddress =
        address(0x6D6f646c65726332307065670000000000000000);

    event DepositActiveStatus(bool indexed active);
    event WithdrawalActiveStatus(bool indexed active);
    event BridgeAddressUpdated(address indexed bridge);
    event PalletAddressUpdated(address indexed palletAddress);
    event Endowed(uint256 indexed amount);

    event Deposit(
        address indexed _address,
        address indexed tokenAddress,
        uint128 indexed amount,
        address destination
    );
    event Withdraw(
        address indexed _address,
        address indexed tokenAddress,
        uint128 indexed amount
    );
    event AdminWithdraw(
        address indexed _address,
        address indexed tokenAddress,
        uint128 indexed amount
    );

    constructor(
        IBridge _bridge,
        IERC20 _token, // Changed from ERC20 to IERC20
        address _rolesManager,
        address _pegManager
    ) {
        bridge = _bridge;
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, _rolesManager);
        _grantRole(PEG_MANAGER_ROLE, _pegManager);
        _grantRole(TOKEN_ROLE, address(_token));
        _grantRole(TOKEN_RECOVERY_ROLE, address(_token));
    }

    function deposit(
        address _tokenAddress, // ? 2Marco: do we need this?
        uint128 _amount,
        address _destination
    ) external payable {
        require(depositsActive, "TP: Deposits paused");

        uint256 bridgeMessageFee = msg.value;

        require(
            msg.value >= bridge.sendMessageFee(),
            "TP: Should include a fee"
        );
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, address(token), _amount, _destination);

        bytes memory message = abi.encode(
            address(token),
            _amount,
            _destination
        );

        bridge.sendMessage{value: bridgeMessageFee}(palletAddress, message);
    }

    function onMessageReceived(
        address _source,
        bytes calldata _message
    ) external override {
        // only accept calls from the bridge contract
        require(msg.sender == address(bridge), "TP: Only bridge can call");
        // Ensure the bridge is active
        require(_source == palletAddress, "TP: must be peg pallet address");

        (address tokenAddress, uint128 amount, address recipient) = abi.decode(
            _message,
            (address, uint128, address)
        );

        require(tokenAddress == address(token), "TP: token not allowed");

        _withdraw(tokenAddress, amount, recipient);
    }

    function _withdraw(
        address _tokenAddress, // ? 2Marco: do we need this?
        uint128 _amount,
        address _recipient
    ) internal nonReentrant {
        require(withdrawalsActive, "TP: Withdrawals paused");

        IERC20(token).safeTransfer(_recipient, _amount);

        emit Withdraw(_recipient, address(token), _amount);
    }

    /// @dev See {IERC165-supportsInterface}. Docs: https://docs.openzeppelin.com/contracts/4.x/api/utils#IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IBridgeReceiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ============================================================================================================= //
    // ============================================== Token Recovery ============================================== //
    // ============================================================================================================= //

    uint256 public reimbursementFee = 10;
    mapping(address => uint256) public refunds;
    uint256 public fees;

    event Stored(address indexed addr, uint256 amount);
    event WithdrawnForFee(address indexed addr, uint256 amount, uint256 fee);
    event AdminWithdrawal(address indexed recipient, uint256 amount);

    function store(address from, uint256 amount) external onlyRole(TOKEN_ROLE) {
        uint256 fee = (amount * reimbursementFee) / 100;
        uint256 refund = amount - fee;
        refunds[from] += refund;
        fees += fee;
        emit Stored(from, refund);
    }

    function setReimbursementFee(
        uint256 _reimbursementFee
    ) external onlyRole(TOKEN_ROLE) {
        require(_reimbursementFee <= 100, "Invalid fee percentage");
        reimbursementFee = _reimbursementFee;
    }

    function withdraw() external nonReentrant {
        address addr = _msgSender();
        uint256 refund = refunds[addr];
        require(refund > 0, "No refund available");
        delete refunds[addr];
        token.transfer(addr, refund);
        emit WithdrawnForFee(addr, refund, reimbursementFee);
    }

    function adminFeesWithdrawal(
        address recipient
    ) external onlyRole(TOKEN_RECOVERY_ROLE) nonReentrant {
        uint256 availableFees = fees;
        require(availableFees > 0, "No fees available");
        require(recipient != address(0), "Invalid recipient address");

        fees = 0;
        token.transfer(recipient, availableFees);
        emit AdminWithdrawal(recipient, availableFees);
    }

    // ============================================================================================================= //
    // ============================================== Admin functions ============================================== //
    // ============================================================================================================= //

    /// @dev Endow the contract with ether
    // ? 2Marco: do we need this?
    function endow() external payable onlyRole(PEG_MANAGER_ROLE) {
        require(msg.value > 0, "TP: Must endow nonzero");
        emit Endowed(msg.value);
    }

    function setDepositsActive(
        bool _active
    ) external onlyRole(PEG_MANAGER_ROLE) {
        depositsActive = _active;
        emit DepositActiveStatus(_active);
    }

    function setWithdrawalsActive(
        bool _active
    ) external onlyRole(PEG_MANAGER_ROLE) {
        withdrawalsActive = _active;
        emit WithdrawalActiveStatus(_active);
    }

    function setBridgeAddress(
        IBridge _bridge
    ) external onlyRole(PEG_MANAGER_ROLE) {
        bridge = _bridge;
        emit BridgeAddressUpdated(address(_bridge));
    }

    function setPalletAddress(
        address _palletAddress
    ) external onlyRole(PEG_MANAGER_ROLE) {
        palletAddress = _palletAddress;
        emit PalletAddressUpdated(_palletAddress);
    }

    function adminEmergencyWithdraw(
        address _tokenAddress,
        uint128 _amount,
        address _recipient
    ) external onlyRole(PEG_MANAGER_ROLE) {
        _withdraw(_tokenAddress, _amount, _recipient);
        emit AdminWithdraw(_recipient, _tokenAddress, _amount);
    }
}
