// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Token.sol";
import "../contracts/TokenPeg.sol";

contract TokenPegRefundTest is Test {
    Token public token;
    TokenPeg public peg;

    address rolesManager = makeAddr("rolesManager");
    address tokenContractManager = makeAddr("tokenContractManager");
    address tokenRecoveryManager = makeAddr("tokenRecoveryManager");
    address multisig = makeAddr("multisig");
    address pegManager = makeAddr("pegManager");
    address user = makeAddr("user");
    address feeRecipient = makeAddr("feeRecipient");

    // Use a smaller amount for testing
    uint256 constant INITIAL_AMOUNT = 100e6; // 100 tokens with 6 decimals

    function setUp() public {
        // Deploy Token contract
        token = new Token(
            rolesManager,
            tokenContractManager,
            tokenRecoveryManager,
            multisig
        );

        // Deploy TokenPeg contract
        peg = new TokenPeg(
            IBridge(address(0)), // Bridge not needed for refund tests
            IERC20(address(token)),
            rolesManager,
            pegManager
        );

        // Initialize token with peg
        vm.prank(tokenContractManager);
        token.init(address(peg));

        // Transfer tokens from peg to user for testing
        vm.prank(address(peg));
        token.transfer(user, INITIAL_AMOUNT);

        // Grant TOKEN_RECOVERY_ROLE to tokenRecoveryManager in peg contract
        vm.prank(rolesManager);
        peg.grantRole(TOKEN_RECOVERY_ROLE, tokenRecoveryManager);
    }

    function test_refund_calculation() public {
        // User sends tokens to peg
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT);

        // Calculate expected values (10% fee)
        uint256 expectedFee = (INITIAL_AMOUNT * 10) / 100;
        uint256 expectedRefund = INITIAL_AMOUNT - expectedFee;

        // Verify refund storage
        assertEq(
            peg.refunds(user),
            expectedRefund,
            "Incorrect refund amount stored"
        );
        assertEq(peg.fees(), expectedFee, "Incorrect fee amount stored");
    }

    function test_withdraw_refund() public {
        // User sends tokens to peg
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT);

        uint256 expectedRefund = (INITIAL_AMOUNT * 90) / 100; // 90% of initial amount

        // Withdraw refund
        vm.prank(user);
        peg.withdraw();

        // Verify state after withdrawal
        assertEq(
            token.balanceOf(user),
            expectedRefund,
            "User didn't receive correct refund"
        );
        assertEq(peg.refunds(user), 0, "Refund not cleared after withdrawal");
    }

    function test_revert_withdraw_with_no_refund() public {
        vm.prank(user);
        vm.expectRevert("No refund available");
        peg.withdraw();
    }

    function test_multiple_refunds() public {
        // First transfer
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT / 2);

        // Second transfer
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT / 2);

        uint256 expectedRefund = (INITIAL_AMOUNT * 90) / 100; // 90% of total amount

        assertEq(
            peg.refunds(user),
            expectedRefund,
            "Incorrect accumulated refund"
        );

        // Withdraw accumulated refund
        vm.prank(user);
        peg.withdraw();

        assertEq(
            token.balanceOf(user),
            expectedRefund,
            "User didn't receive correct accumulated refund"
        );
    }

    function test_admin_fees_withdrawal() public {
        // Generate fees by having user transfer tokens
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT);

        uint256 expectedFee = (INITIAL_AMOUNT * 10) / 100;

        // Verify initial state
        assertEq(peg.fees(), expectedFee, "Initial fees incorrect");
        assertEq(
            token.balanceOf(feeRecipient),
            0,
            "Fee recipient should start with 0 balance"
        );

        // Withdraw fees as token recovery manager
        vm.prank(tokenRecoveryManager);
        peg.adminFeesWithdrawal(feeRecipient);

        // Verify final state
        assertEq(peg.fees(), 0, "Fees should be cleared after withdrawal");
        assertEq(
            token.balanceOf(feeRecipient),
            expectedFee,
            "Fee recipient should receive correct amount"
        );
    }

    function test_revert_admin_fees_withdrawal_unauthorized() public {
        // Generate some fees
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT);

        // Attempt withdrawal as unauthorized user
        vm.prank(user);
        vm.expectRevert();
        peg.adminFeesWithdrawal(feeRecipient);
    }

    function test_revert_admin_fees_withdrawal_no_fees() public {
        // Attempt withdrawal with no fees
        vm.prank(tokenRecoveryManager);
        vm.expectRevert("No fees available");
        peg.adminFeesWithdrawal(feeRecipient);
    }

    function test_revert_admin_fees_withdrawal_zero_address() public {
        // Generate some fees
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT);

        // Attempt withdrawal to zero address
        vm.prank(tokenRecoveryManager);
        vm.expectRevert("Invalid recipient address");
        peg.adminFeesWithdrawal(address(0));
    }

    function test_admin_fees_withdrawal_multiple_deposits() public {
        // Generate fees from multiple deposits
        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT / 2);

        vm.prank(user);
        token.transfer(address(peg), INITIAL_AMOUNT / 2);

        uint256 expectedTotalFee = (INITIAL_AMOUNT * 10) / 100;

        assertEq(peg.fees(), expectedTotalFee, "Incorrect total fees");

        // Withdraw accumulated fees
        vm.prank(tokenRecoveryManager);
        peg.adminFeesWithdrawal(feeRecipient);

        // Verify final state
        assertEq(peg.fees(), 0, "Fees should be cleared after withdrawal");
        assertEq(
            token.balanceOf(feeRecipient),
            expectedTotalFee,
            "Fee recipient should receive correct total amount"
        );
    }
}
