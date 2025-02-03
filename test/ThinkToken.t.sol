// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/ThinkToken.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "forge-std/Test.sol";
import "../contracts/Roles.sol";

contract ThinkTokenTest is Test {
    ThinkToken token;
    address[] users;
    address manager;
    address multisig;
    address user;
    address peg;

    uint256 constant INITIAL_SUPPLY = 1_000_000_000e6;
    uint256 constant TEST_AMOUNT = 1000;

    function setUp() public {
        users = new UserFactory().create(3);
        manager = users[0];
        multisig = users[1];
        user = users[2];
        peg = address(0x123);

        token = new ThinkToken(manager, multisig);

        // Initialize the token
        vm.prank(manager);
        token.init(peg);

        // Transfer some tokens from peg to multisig for testing
        vm.prank(peg);
        token.transfer(multisig, TEST_AMOUNT * 10);
    }

    function test_initial_state() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(peg), INITIAL_SUPPLY - (TEST_AMOUNT * 10));
        assertTrue(token.hasRole(MANAGER_ROLE, manager));
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
        address recipient = makeAddr("recipient"); // Create a proper address

        // Transfer some tokens to user for testing
        vm.prank(multisig);
        token.transfer(user, TEST_AMOUNT);
        assertEq(
            token.balanceOf(user),
            TEST_AMOUNT,
            "User should have received tokens"
        );

        // Test pause by manager
        vm.prank(manager);
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
        vm.prank(manager);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(manager), 20),
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
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(user), 20),
                " is missing role ",
                Strings.toHexString(uint256(MANAGER_ROLE), 32)
            )
        );
        token.addManager(newManager);

        // Test authorized manager addition
        vm.prank(manager);
        token.addManager(newManager);
        assertTrue(token.hasRole(MANAGER_ROLE, newManager));

        // Test manager removal
        vm.prank(manager);
        token.removeManager(newManager);
        assertFalse(token.hasRole(MANAGER_ROLE, newManager));
    }

    function test_multisig_revocation() public {
        // Test unauthorized multisig revocation
        vm.prank(user);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(user), 20),
                " is missing role ",
                Strings.toHexString(uint256(MANAGER_ROLE), 32)
            )
        );
        token.revokeMultisig(multisig);

        // Test authorized multisig revocation
        vm.prank(manager);
        token.revokeMultisig(multisig);
        assertFalse(token.hasRole(MULTISIG_ROLE, multisig));
    }
}
