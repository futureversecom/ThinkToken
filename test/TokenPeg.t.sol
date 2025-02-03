// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/TokenPeg.sol";
import "../contracts/Token.sol";
import "../contracts/Bridge.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "forge-std/Test.sol";
import "../contracts/Roles.sol";

contract TokenPegTest is Test {
    TokenPeg peg;
    Token token;
    Bridge bridge;
    address[] users;
    address rolesManager;
    address pegManager;
    address recoveryManager;
    address user;

    uint128 constant TEST_AMOUNT = 1000;
    uint256 constant BRIDGE_FEE = 0.01 ether;

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
    event DepositActiveStatus(bool indexed active);
    event WithdrawalActiveStatus(bool indexed active);
    event BridgeAddressUpdated(address indexed bridge);
    event PalletAddressUpdated(address indexed palletAddress);

    function _getAccessControlRevertMessage(
        address account,
        bytes32 role
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(account), 20),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            );
    }

    function setUp() public {
        users = new UserFactory().create(4);
        rolesManager = users[0];
        pegManager = users[1];
        recoveryManager = users[2];
        user = users[3];

        // Deploy and setup bridge
        bridge = new Bridge();
        // Set bridge active using the actual setter (our test contract is the owner)
        bridge.setActive(true);

        // Set the bridge's message fee
        vm.mockCall(
            address(bridge),
            abi.encodeWithSelector(IBridge.sendMessageFee.selector),
            abi.encode(BRIDGE_FEE)
        );

        // Deploy and setup token
        token = new Token(
            rolesManager,
            pegManager,
            recoveryManager,
            pegManager
        );
        vm.prank(pegManager);
        token.init(address(this));

        // Deploy peg
        peg = new TokenPeg(
            bridge,
            token,
            rolesManager,
            recoveryManager,
            pegManager
        );

        // Setup initial state
        vm.prank(pegManager);
        peg.setDepositsActive(true);
        vm.prank(pegManager);
        peg.setWithdrawalsActive(true);

        // Fund user with tokens
        token.transfer(user, TEST_AMOUNT * 2);
    }

    function test_initial_state() public {
        assertTrue(peg.depositsActive());
        assertTrue(peg.withdrawalsActive());
        assertEq(address(peg.token()), address(token));
        assertEq(address(peg.bridge()), address(bridge));
        assertTrue(peg.hasRole(PEG_MANAGER_ROLE, pegManager));
    }

    function test_deposit() public {
        address destination = makeAddr("destination");
        uint128 amount = TEST_AMOUNT;

        // Ensure bridge is active
        bridge.setActive(true);

        // Approve tokens
        vm.startPrank(user);
        token.approve(address(peg), amount);

        // Test deposit
        vm.expectEmit(true, true, true, true, address(peg));
        emit Deposit(user, address(token), amount, destination);

        peg.deposit{value: BRIDGE_FEE}(address(token), amount, destination);
        vm.stopPrank();

        assertEq(token.balanceOf(address(peg)), amount);
    }

    function test_deposit_when_paused() public {
        // Pause deposits
        vm.prank(pegManager);
        peg.setDepositsActive(false);

        vm.startPrank(user);
        token.approve(address(peg), TEST_AMOUNT);

        vm.expectRevert("TP: Deposits paused");
        peg.deposit{value: BRIDGE_FEE}(
            address(token),
            TEST_AMOUNT,
            makeAddr("destination")
        );
        vm.stopPrank();
    }

    function test_deposit_insufficient_fee() public {
        vm.startPrank(user);
        token.approve(address(peg), TEST_AMOUNT);

        vm.expectRevert("TP: Should include a fee");
        peg.deposit{value: BRIDGE_FEE - 1}(
            address(token),
            TEST_AMOUNT,
            makeAddr("destination")
        );
        vm.stopPrank();
    }

    function test_message_received() public {
        address recipient = makeAddr("recipient");
        uint128 amount = TEST_AMOUNT;

        // Ensure bridge is active for deposit and message receiving
        bridge.setActive(true);

        // Deposit tokens first
        vm.startPrank(user);
        token.approve(address(peg), amount);
        peg.deposit{value: BRIDGE_FEE}(address(token), amount, recipient);
        vm.stopPrank();

        // Prepare withdrawal message
        bytes memory message = abi.encode(address(token), amount, recipient);

        // Call onMessageReceived as bridge (active)
        vm.startPrank(address(bridge));
        peg.onMessageReceived(peg.palletAddress(), message);
        vm.stopPrank();
        assertEq(token.balanceOf(recipient), amount);
    }

    function test_unauthorized_message() public {
        bytes memory message = abi.encode(
            address(token),
            TEST_AMOUNT,
            makeAddr("recipient")
        );

        // Ensure bridge is active for first part
        bridge.setActive(true);

        // Test unauthorized sender (not from bridge)

        address notBridge = makeAddr("notBridge");
        address palletAddress = peg.palletAddress();
        vm.startPrank(notBridge);
        vm.expectRevert(bytes("TP: Only bridge can call"));
        peg.onMessageReceived(palletAddress, message);
        vm.stopPrank();

        // Test unauthorized source: call from bridge but _source not equal to palletAddress
        vm.startPrank(address(bridge));
        vm.expectRevert("TP: must be peg pallet address");
        peg.onMessageReceived(makeAddr("unauthorized"), message);
        vm.stopPrank();
    }

    function test_admin_functions() public {
        // Test setDepositsActive
        vm.startPrank(pegManager);

        vm.expectEmit(true, false, false, true, address(peg));
        emit DepositActiveStatus(false);
        peg.setDepositsActive(false);
        assertFalse(peg.depositsActive());

        // Test setWithdrawalsActive
        vm.expectEmit(true, false, false, true, address(peg));
        emit WithdrawalActiveStatus(false);
        peg.setWithdrawalsActive(false);
        assertFalse(peg.withdrawalsActive());

        // Test setBridgeAddress
        Bridge newBridge = new Bridge();
        vm.expectEmit(true, false, false, true, address(peg));
        emit BridgeAddressUpdated(address(newBridge));
        peg.setBridgeAddress(newBridge);
        assertEq(address(peg.bridge()), address(newBridge));

        // Test setPalletAddress
        address newPallet = makeAddr("newPallet");
        vm.expectEmit(true, false, false, true, address(peg));
        emit PalletAddressUpdated(newPallet);
        peg.setPalletAddress(newPallet);
        assertEq(peg.palletAddress(), newPallet);

        vm.stopPrank();
    }

    function test_unauthorized_admin_functions() public {
        vm.startPrank(user);

        vm.expectRevert(_getAccessControlRevertMessage(user, PEG_MANAGER_ROLE));
        peg.setDepositsActive(false);

        vm.expectRevert(_getAccessControlRevertMessage(user, PEG_MANAGER_ROLE));
        peg.setWithdrawalsActive(false);

        vm.expectRevert(_getAccessControlRevertMessage(user, PEG_MANAGER_ROLE));
        peg.setBridgeAddress(IBridge(address(0)));

        vm.expectRevert(_getAccessControlRevertMessage(user, PEG_MANAGER_ROLE));
        peg.setPalletAddress(address(0));

        vm.stopPrank();
    }

    function test_interface_support() public {
        assertTrue(peg.supportsInterface(type(IBridgeReceiver).interfaceId));
    }
}
