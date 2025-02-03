// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../contracts/TokenRecovery.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/Roles.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockToken is TokenRecovery {
    constructor(
        address tokenRecoveryManager
    ) TokenRecovery(tokenRecoveryManager) {}

    function deposit(address to, uint256 amount) external {
        _deposit(to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return true;
    }
}

contract TokenRecoveryTest is Test {
    MockToken recovery;
    address[] users;
    address manager;
    address user;

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
        users = new UserFactory().create(2);
        manager = users[0];
        user = users[1];
        recovery = new MockToken(manager);
    }

    function test_initial_state() public {
        assertEq(
            recovery.getReimbursementFee(),
            10,
            "Initial fee should be 10%"
        );
        assertEq(recovery.getFees(), 0, "Initial fees should be 0");
        assertTrue(
            recovery.hasRole(TOKEN_RECOVERY_ROLE, manager),
            "Manager should have TOKEN_RECOVERY_ROLE"
        );
    }

    function test_set_reimbursement_fee() public {
        vm.prank(manager);
        recovery.setReimbursementFee(20);
        assertEq(
            recovery.getReimbursementFee(),
            20,
            "Fee should be updated to 20%"
        );
    }

    function test_set_reimbursement_fee_unauthorized() public {
        vm.prank(user);
        vm.expectRevert(
            _getAccessControlRevertMessage(user, TOKEN_RECOVERY_ROLE)
        );
        recovery.setReimbursementFee(20);
    }

    function test_deposit_calculation() public {
        uint256 depositAmount = 1000;
        uint256 expectedFee = (depositAmount * 10) / 100; // 10% of 1000
        uint256 expectedRefund = depositAmount - expectedFee;

        vm.prank(user);
        recovery.deposit(address(recovery), depositAmount);

        assertEq(
            recovery.refunds(user),
            expectedRefund,
            "Refund amount should be correct"
        );
        assertEq(
            recovery.getFees(),
            expectedFee,
            "Fee amount should be correct"
        );
    }

    function test_withdraw_refund() public {
        // Setup: Create a deposit first
        uint256 depositAmount = 1000;
        vm.prank(user);
        recovery.deposit(address(recovery), depositAmount);

        uint256 expectedRefund = depositAmount - ((depositAmount * 10) / 100);

        // Mock ERC20 transfer
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        vm.expectEmit(true, true, false, true);
        emit WithdrawnForFee(user, expectedRefund, 10);

        vm.prank(user);
        recovery.withdraw();

        assertEq(
            recovery.refunds(user),
            0,
            "Refund should be cleared after withdrawal"
        );
    }

    function test_admin_withdrawal() public {
        // Setup: Create some fees
        uint256 depositAmount = 1000;
        uint256 expectedFee = (depositAmount * 10) / 100;

        vm.prank(user);
        recovery.deposit(address(recovery), depositAmount);

        // Mock ERC20 transfer
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        vm.expectEmit(true, true, false, true);
        emit AdminWithdrawal(manager, expectedFee);

        vm.prank(manager);
        recovery.adminFeesWithdrawal(manager);

        assertEq(
            recovery.getFees(),
            0,
            "Fees should be cleared after withdrawal"
        );
    }

    function test_admin_withdrawal_no_fees() public {
        vm.prank(manager);
        vm.expectRevert("No fees available");
        recovery.adminFeesWithdrawal(manager);
    }

    function test_admin_withdrawal_zero_address() public {
        // Setup: Create some fees
        vm.prank(user);
        recovery.deposit(address(recovery), 1000);

        vm.prank(manager);
        vm.expectRevert("Invalid recipient address");
        recovery.adminFeesWithdrawal(address(0));
    }

    function test_admin_withdrawal_unauthorized() public {
        vm.prank(user);
        vm.expectRevert(
            _getAccessControlRevertMessage(user, TOKEN_RECOVERY_ROLE)
        );
        recovery.adminFeesWithdrawal(user);
    }

    function test_receive_function() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(); // Empty revert without message
        payable(address(recovery)).transfer(1 ether);
    }

    function test_deposit_zero_amount() public {
        vm.prank(user);
        recovery.deposit(address(recovery), 0);
        assertEq(recovery.refunds(user), 0, "No refund for zero deposit");
        assertEq(recovery.getFees(), 0, "No fees for zero deposit");
    }

    function test_deposit_to_other_address() public {
        vm.prank(user);
        recovery.deposit(address(0x123), 1000);
        assertEq(recovery.refunds(user), 0, "No refund for external deposit");
        assertEq(recovery.getFees(), 0, "No fees for external deposit");
    }

    function test_withdraw_zero_refund() public {
        vm.prank(user);
        recovery.withdraw();
        assertEq(recovery.refunds(user), 0, "Refund should remain zero");
    }

    function test_multiple_deposits() public {
        vm.startPrank(user);

        uint256 firstDeposit = 1000;
        uint256 secondDeposit = 500;

        recovery.deposit(address(recovery), firstDeposit);
        recovery.deposit(address(recovery), secondDeposit);

        uint256 totalDeposit = firstDeposit + secondDeposit;
        uint256 expectedFee = (totalDeposit * 10) / 100;
        uint256 expectedRefund = totalDeposit - expectedFee;

        assertEq(
            recovery.refunds(user),
            expectedRefund,
            "Refund should accumulate correctly"
        );
        assertEq(
            recovery.getFees(),
            expectedFee,
            "Fees should accumulate correctly"
        );

        vm.stopPrank();
    }

    function test_set_reimbursement_fee_limits() public {
        uint256 DEPOSIT_AMOUNT = 1000;

        vm.startPrank(manager);

        // Test 0% fee
        recovery.setReimbursementFee(0);
        assertEq(recovery.getReimbursementFee(), 0, "Fee should be set to 0%");

        // Verify deposit with 0% fee
        vm.stopPrank();
        vm.prank(user);
        recovery.deposit(address(recovery), DEPOSIT_AMOUNT);
        assertEq(
            recovery.refunds(user),
            DEPOSIT_AMOUNT,
            "Full amount should be refunded with 0% fee"
        );
        assertEq(
            recovery.getFees(),
            0,
            "No fees should be collected with 0% fee"
        );

        // Reset state for next test
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        vm.prank(user);
        recovery.withdraw();
        // Clear the mock to avoid interference
        vm.clearMockedCalls();

        // Test 100% fee
        vm.prank(manager);
        recovery.setReimbursementFee(100);
        assertEq(
            recovery.getReimbursementFee(),
            100,
            "Fee should be set to 100%"
        );

        // Verify deposit with 100% fee
        vm.prank(user);
        recovery.deposit(address(recovery), DEPOSIT_AMOUNT);
        assertEq(
            recovery.refunds(user),
            0,
            "No refund should be given with 100% fee"
        );
        assertEq(
            recovery.getFees(),
            DEPOSIT_AMOUNT,
            "All funds should go to fees with 100% fee"
        );

        // Mock transfer for admin withdrawal
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        vm.prank(manager);
        recovery.adminFeesWithdrawal(manager);

        // Test invalid fee percentage
        vm.prank(manager);
        vm.expectRevert("Invalid fee percentage");
        recovery.setReimbursementFee(101);

        vm.stopPrank();
    }

    function test_failed_transfer_on_withdraw() public {
        // Setup: Create a deposit
        vm.prank(user);
        recovery.deposit(address(recovery), 1000);

        // Mock failed transfer
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );

        // Attempt withdrawal
        vm.prank(user);
        vm.expectRevert("ERC20 transfer failed");
        recovery.withdraw();

        // Verify state wasn't changed
        assertEq(
            recovery.refunds(user),
            900, // Original deposit minus 10% fee
            "Refund should remain unchanged after failed transfer"
        );
    }

    function test_multiple_withdrawals() public {
        // Setup initial deposit
        uint256 depositAmount = 1000;
        uint256 expectedRefund = depositAmount - ((depositAmount * 10) / 100);

        vm.prank(user);
        recovery.deposit(address(recovery), depositAmount);

        // Mock ERC20 transfer for both withdrawals
        vm.mockCall(
            address(recovery),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );

        // First withdrawal
        vm.expectEmit(true, true, false, true);
        emit WithdrawnForFee(user, expectedRefund, 10);
        vm.prank(user);
        recovery.withdraw();

        // Second withdrawal should have no effect
        vm.prank(user);
        recovery.withdraw();
        assertEq(
            recovery.getFees(),
            depositAmount / 10,
            "Fees should remain unchanged"
        );
        assertEq(
            recovery.refunds(user),
            0,
            "Refund should remain zero after multiple withdrawals"
        );
    }
}
