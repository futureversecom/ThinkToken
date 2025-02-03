// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IBridge.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Roles.sol";
import "./TokenRecovery.sol";

/// @title ERC20 Peg contract on ethereum
/// @author Root Network
/// @notice Provides an Eth/ERC20/GA Root network peg
///  - depositing: lock Eth/ERC20 tokens to redeem Root network "generic asset" (GA) 1:1
///  - withdrawing: burn or lock GAs to redeem Eth/ERC20 tokens 1:1
contract ThinkTokenPeg is TokenRecovery, Ownable, IBridgeReceiver {
    using SafeERC20 for IERC20;

    address public ThinkToken;

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

    event ThinkTokenUpdated(address indexed ThinkToken);

    constructor(
        IBridge _bridge,
        address _ThinkToken,
        address tokenRecoveryManager,
        address pegManager
    ) TokenRecovery(tokenRecoveryManager) {
        bridge = _bridge;
        ThinkToken = _ThinkToken;
        _grantRole(PEG_MANAGER_ROLE, pegManager);
    }

    /// @notice Deposit amount of tokenAddress the pegged version of the token will be claim-able on Root network.
    function deposit(
        address _tokenAddress,
        uint128 _amount,
        address _destination
    ) external payable {
        require(depositsActive, "RTP: Deposits paused");
        require(_tokenAddress == ThinkToken, "RTP: Only ROOT token allowed");

        uint256 bridgeMessageFee = msg.value;

        require(
            msg.value >= bridge.sendMessageFee(),
            "RTP: Should include a fee"
        );
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        emit Deposit(msg.sender, _tokenAddress, _amount, _destination);

        // send message to bridge - with fee to feeRecipient via bridge
        bytes memory message = abi.encode(_tokenAddress, _amount, _destination);

        bridge.sendMessage{value: bridgeMessageFee}(palletAddress, message);
    }

    function onMessageReceived(
        address _source,
        bytes calldata _message
    ) external override {
        // only accept calls from the bridge contract
        require(msg.sender == address(bridge), "RTP: Only bridge can call");
        // only accept messages from the peg pallet
        require(_source == palletAddress, "RTP: must be peg pallet address");

        (address tokenAddress, uint128 amount, address recipient) = abi.decode(
            _message,
            (address, uint128, address)
        );

        require(tokenAddress == ThinkToken, "RTP: Only ROOT token allowed");

        _withdraw(tokenAddress, amount, recipient);
    }

    /// @notice Withdraw tokens from this contract
    /// Requires signatures from a threshold of current Root network validators.
    function _withdraw(
        address _tokenAddress,
        uint128 _amount,
        address _recipient
    ) internal nonReentrant {
        require(withdrawalsActive, "RTP: Withdrawals paused");

        SafeERC20.safeTransfer(IERC20(_tokenAddress), _recipient, _amount);

        emit Withdraw(_recipient, _tokenAddress, _amount);
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
    // ============================================== Admin functions ============================================== //
    // ============================================================================================================= //

    /// @dev Endow the contract with ether
    function endow() external payable onlyRole(PEG_MANAGER_ROLE) {
        require(msg.value > 0, "RTP: Must endow nonzero");
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

    function setThinkToken(
        address _ThinkToken
    ) external onlyRole(PEG_MANAGER_ROLE) {
        ThinkToken = _ThinkToken;
        emit ThinkTokenUpdated(_ThinkToken);
    }
}
