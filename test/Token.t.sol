// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/Token.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "forge-std/Test.sol";
import "../contracts/Roles.sol";

contract ThinkTokenTest is Test {
    Token token;
    address[] users;
    address rolesManager;
    address tokenManager;
    address recoveryManager;
    address multisig;
    address user;
    address peg;

    uint256 constant INITIAL_SUPPLY = 1_000_000_000e6;
    uint256 constant TEST_AMOUNT = 1000;

    event Deposited(address indexed addr, uint256 amount);
    event WithdrawnForFee(address indexed addr, uint256 amount, uint256 fee);
    event AdminWithdrawal(address indexed recipient, uint256 amount);

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
        users = new UserFactory().create(3);
        rolesManager = users[0];
        tokenManager = users[0]; // Using same address for testing
        recoveryManager = users[0]; // Using same address for testing
        multisig = users[1];
        user = users[2];
        peg = address(0x123);

        token = new Token(
            rolesManager,
            tokenManager,
            recoveryManager,
            multisig
        );

        // Initialize the token
        vm.prank(tokenManager);
        token.init(peg);

        // Transfer some tokens from peg to multisig for testing
        vm.prank(peg);
        token.transfer(multisig, TEST_AMOUNT * 10);
    }

    function test_initial_state() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(peg), INITIAL_SUPPLY - (TEST_AMOUNT * 10));
        assertTrue(token.hasRole(MANAGER_ROLE, tokenManager));
        assertTrue(token.hasRole(MULTISIG_ROLE, multisig));
    }

    function test_burn_functionality() public {
        uint256 burnAmount = TEST_AMOUNT / 2;

        vm.startPrank(multisig);
        token.burn(burnAmount);
        assertEq(token.balanceOf(multisig), (TEST_AMOUNT * 10) - burnAmount);
        vm.stopPrank();

        // Test unauthorized burn
        vm.prank(user);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(user), 20),
                " is missing role ",
                Strings.toHexString(uint256(MULTISIG_ROLE), 32)
            )
        );
        token.burn(100);
    }

    function test_pause_mechanism() public {
        address recipient = makeAddr("recipient");

        // Transfer some tokens to user for testing
        vm.prank(multisig);
        token.transfer(user, TEST_AMOUNT);

        // Test pause by manager
        vm.prank(tokenManager);
        token.pause();
        assertTrue(token.paused());

        // Test transfer while paused
        vm.prank(user);
        vm.expectRevert("Token transfers are paused");
        token.transfer(recipient, TEST_AMOUNT / 2);
        assertEq(
            token.balanceOf(user),
            TEST_AMOUNT,
            "Balance should remain unchanged while paused"
        );

        // Test unauthorized unpause
        vm.prank(tokenManager);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(tokenManager), 20),
                " is missing role ",
                Strings.toHexString(uint256(MULTISIG_ROLE), 32)
            )
        );
        token.unpause();
        assertTrue(token.paused(), "Token should still be paused");

        // Test authorized unpause
        vm.prank(multisig);
        token.unpause();
        assertFalse(token.paused());

        // Test transfer after unpause
        uint256 transferAmount = TEST_AMOUNT / 2;
        vm.prank(user);
        token.transfer(recipient, transferAmount);
        assertEq(
            token.balanceOf(recipient),
            transferAmount,
            "Recipient should have received tokens"
        );
        assertEq(
            token.balanceOf(user),
            TEST_AMOUNT - transferAmount,
            "Sender balance should be reduced"
        );
    }

    function test_role_management() public {
        address newManager = address(0x456);

        // Test unauthorized manager addition
        vm.prank(user);
        vm.expectRevert(
            _getAccessControlRevertMessage(user, DEFAULT_ADMIN_ROLE)
        );
        token.grantRole(MANAGER_ROLE, newManager);

        // Test authorized manager addition
        vm.prank(rolesManager);
        token.grantRole(MANAGER_ROLE, newManager);
        assertTrue(token.hasRole(MANAGER_ROLE, newManager));

        // Test manager removal
        vm.prank(rolesManager);
        token.revokeRole(MANAGER_ROLE, newManager);
        assertFalse(token.hasRole(MANAGER_ROLE, newManager));
    }

    function test_double_initialization() public {
        vm.startPrank(tokenManager);
        address newPeg = makeAddr("newPeg");
        vm.expectRevert("Already initialized");
        token.init(newPeg);
        vm.stopPrank();
    }

    function test_initialization_zero_address() public {
        // Create new token without initialization
        token = new Token(
            rolesManager,
            tokenManager,
            recoveryManager,
            multisig
        );

        vm.prank(tokenManager);
        vm.expectRevert("Invalid peg address");
        token.init(address(0));
    }

    function test_unauthorized_initialization() public {
        vm.prank(user);
        vm.expectRevert(_getAccessControlRevertMessage(user, MANAGER_ROLE));
        token.init(address(0x123));
    }

    function test_unauthorized_pause() public {
        vm.prank(user);
        vm.expectRevert(_getAccessControlRevertMessage(user, MANAGER_ROLE));
        token.pause();
    }

    function test_unauthorized_unpause() public {
        // Setup: pause first
        vm.prank(tokenManager);
        token.pause();

        vm.prank(user);
        vm.expectRevert(_getAccessControlRevertMessage(user, MULTISIG_ROLE));
        token.unpause();
    }

    function test_unpause_when_not_paused() public {
        // First pause
        vm.prank(tokenManager);
        token.pause();

        vm.prank(multisig);
        token.unpause(); // Should not revert
        assertFalse(token.paused());
    }

    function test_transfer_when_paused() public {
        // Setup: Transfer some tokens and pause
        vm.prank(multisig);
        token.transfer(user, TEST_AMOUNT);

        vm.prank(tokenManager);
        token.pause();

        // Try various transfer scenarios while paused
        vm.startPrank(user);
        address recipient = makeAddr("recipient");

        vm.expectRevert("Token transfers are paused");
        token.transfer(recipient, TEST_AMOUNT / 2);

        // Approve should work even when paused
        token.approve(recipient, TEST_AMOUNT);

        // Setup allowance for transferFrom
        vm.stopPrank();
        vm.prank(recipient);
        vm.expectRevert("Token transfers are paused");
        token.transferFrom(user, recipient, TEST_AMOUNT);
    }

    function test_decimals() public {
        assertEq(token.decimals(), 6, "Token should have 6 decimals");
    }

    function test_token_recovery() public {
        uint256 amount = TEST_AMOUNT;
        uint256 fee = (amount * 10) / 100;
        uint256 refund = amount - fee;

        // Transfer tokens to contract
        vm.startPrank(multisig);
        token.transfer(address(token), amount);

        // Verify deposit was processed
        assertEq(token.refunds(multisig), refund, "Refund amount incorrect");

        // Rely on the actual ERC20 transfer implementation for withdrawal.
        vm.expectEmit(true, true, false, true, address(token));
        emit WithdrawnForFee(multisig, refund, 10);
        token.withdraw();
        vm.stopPrank();
    }
}
