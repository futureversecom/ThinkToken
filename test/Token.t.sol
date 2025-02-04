// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/Token.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "forge-std/Test.sol";
import "@openzeppelin/lib/forge-std/src/Test.sol";
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
    uint256 constant TEST_AMOUNT = 100e6;

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
        users = new UserFactory().create(5);
        rolesManager = users[0];
        tokenManager = users[1];
        recoveryManager = users[2]; // Using same address for testing
        multisig = users[3];
        user = users[4];
        peg = address(0x123);
        vm.label(peg, "peg");

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
        vm.startPrank(peg);
        token.transfer(user, TEST_AMOUNT);
        token.transfer(multisig, TEST_AMOUNT * 10);
        vm.stopPrank();
    }

    function test_initial_state() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(peg), INITIAL_SUPPLY - (TEST_AMOUNT * 11)); // 10 multisig + 1 user
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
        uint256 transferAmount = TEST_AMOUNT;
        uint256 fee = (transferAmount * 10) / 100;
        uint256 refund = transferAmount - fee;

        // Transfer tokens to contract
        vm.startPrank(user);
        token.approve(address(token), transferAmount);
        token.transfer(address(token), transferAmount);

        // Verify deposit state
        assertEq(token.refunds(user), refund, "Refund amount incorrect");
        assertEq(token.balanceOf(user), 0, "User balance should be 0");
        assertEq(
            token.balanceOf(address(token)),
            transferAmount,
            "Token balance should be TEST_AMOUNT"
        );
        assertEq(token.fees(), fee, "Fee amount incorrect");

        // Test withdrawal
        vm.expectEmit(true, true, false, true, address(token));
        emit WithdrawnForFee(user, refund, 10);
        token.withdraw();
        vm.stopPrank();

        // Verify final state
        assertEq(token.balanceOf(user), refund);
        assertEq(token.balanceOf(address(token)), fee);
        assertEq(token.refunds(user), 0);
    }

    function test_mint_functionality() public {
        // Should only mint up to cap
        uint256 remainingMint = token.cap() - token.totalSupply();
        address recipient = makeAddr("new_holder");

        vm.prank(multisig);
        token.mint(recipient, remainingMint);

        assertEq(token.balanceOf(recipient), remainingMint);
        assertEq(token.totalSupply(), token.cap());

        // Verify cap enforcement
        vm.prank(multisig);
        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(recipient, 1);
    }

    function test_fee_configuration() public {
        uint256 newFee = 20;

        // Test unauthorized fee change
        vm.prank(user);
        vm.expectRevert(
            _getAccessControlRevertMessage(user, TOKEN_RECOVERY_ROLE)
        );
        token.setReimbursementFee(newFee);

        // Test authorized fee change
        vm.prank(recoveryManager);
        token.setReimbursementFee(newFee);
        assertEq(token.reimbursementFee(), newFee);

        // Test invalid fee percentage
        vm.prank(recoveryManager);
        vm.expectRevert("Invalid fee percentage");
        token.setReimbursementFee(101);
    }

    function test_admin_fee_withdrawal() public {
        uint256 transferAmount = TEST_AMOUNT;
        uint256 expectedFee = (transferAmount * 10) / 100;
        uint256 initialMultisigBalance = token.balanceOf(multisig);

        // Setup fees by transferring to contract
        vm.startPrank(user);
        token.approve(address(token), transferAmount);
        token.transfer(address(token), transferAmount);
        vm.stopPrank();

        // Verify contract balance and fees
        assertEq(token.balanceOf(address(token)), transferAmount);
        assertEq(token.fees(), expectedFee);

        // Admin withdraws fees
        vm.prank(users[2]); // recoveryManager
        token.adminFeesWithdrawal(multisig);

        // Verify balances after withdrawal
        assertEq(
            token.balanceOf(multisig),
            initialMultisigBalance + expectedFee
        );
        assertEq(token.fees(), 0);
        assertEq(token.balanceOf(address(token)), transferAmount - expectedFee);
    }

    function test_transfer_to_contract() public {
        uint256 transferAmount = TEST_AMOUNT;
        uint256 expectedFee = (transferAmount * 10) / 100;

        assertEq(token.balanceOf(user), transferAmount);

        vm.startPrank(user);
        token.approve(address(token), transferAmount);
        token.transfer(address(token), transferAmount);
        vm.stopPrank();

        assertEq(token.refunds(user), transferAmount - expectedFee);
        assertEq(token.fees(), expectedFee);
        assertEq(token.balanceOf(address(token)), transferAmount);
    }

    function test_receive_ether_reverts() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool success, ) = address(token).call{value: 1 ether}("");
        assertFalse(success, "Should not accept ETH");
    }

    function test_pause_unauthorized_unpause_attempt() public {
        // Try to unpause when not paused
        vm.prank(multisig);
        vm.expectRevert("Pausable: not paused");
        token.unpause();
    }

    function test_max_supply_enforcement() public {
        uint256 maxMint = token.cap() - token.totalSupply();

        vm.startPrank(multisig);
        token.mint(multisig, maxMint);

        vm.expectRevert("ERC20Capped: cap exceeded");
        token.mint(multisig, 1);
    }

    function test_transfer_zero_amount() public {
        address recipient = makeAddr("recipient");
        vm.prank(user);
        token.transfer(recipient, 0); // Should not revert
        assertEq(token.balanceOf(recipient), 0);
    }
}
