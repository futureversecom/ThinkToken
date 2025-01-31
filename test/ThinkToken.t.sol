// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../contracts/ThinkToken.sol";
import "../contracts/ThinkTokenPeg.sol";
import "../contracts/Bridge.sol";
import "../contracts/IBridge.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "ds-test/test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/**
 * @dev Tests for the ASM The Next Legend - Character contract
 */
contract ThinkTokenTestContract is DSTest {
    ThinkToken t_;
    ThinkTokenPeg p_;
    Bridge b_;

    uint256 fee;

    address[] users = new UserFactory().create(3);
    // address user = address(bytes20(uint160(uint256(keccak256("user")))));
    address manager = users[0];
    address multisig = users[1];
    address user = users[2];
    address deployer = address(this);

    string wrongMultisig = getRoleErrorMessage(user, MULTISIG);
    string wrongManager = getRoleErrorMessage(user, MANAGER);

    uint128 testingAmount = 100 * 10e6;

    // Cheat codes are state changing methods called from the address:
    // 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    event BytesEvent(bytes hash);
    event Bytes32Event(bytes32 hash);
    event SignerUpdated(address indexed manager, address newSigner);
    event Separated(
        address indexed to,
        address indexed nftAddress,
        uint256 indexed nftId,
        address transferTo
    );

    /** ----------------------------------
     * ! Setup
     * ----------------------------------- */

    // The state of the contract gets reset before each
    // test is run, with the `setUp()` function being called
    // each time after deployment. Think of this like a JavaScript
    // `beforeEach` block
    function setUp() public {
        b_ = new Bridge();
        b_.setActive(true);
        fee = b_.sendMessageFee();
        t_ = new ThinkToken(manager, multisig);
        p_ = new ThinkTokenPeg(IBridge(b_), address(t_));

        // ! For testing purpose we'll skip init() phase
        // ! See test_mint_capped() test where we calling init()
        // vm.prank(manager);
        // t_.init(address(p_));

        p_.setDepositsActive(true);
    }

    function test_contracts_states() public view skip(false) {
        console.log("Bridge address: %s", address(b_));
        console.log("Bridge fee: %s", fee);
        console.log("ThinkToken address: %s", address(t_));
        console.log("ThinkTokenPeg address: %s", address(p_));
        console.log("ThinkToken totalSupply: %s", t_.totalSupply());
        console.log("ThinkToken balance of PEG: %s", t_.balanceOf(address(p_)));
    }

    /** ----------------------------------
     * ! Business logic Tests
     * ----------------------------------- */

    function test_mint_happy_path() public skip(false) {
        /** -------------------------------------------------------
         * @notice Minting happy path
         * --------------------------------------------------------
         * @notice GIVEN: non-zero amount and non-zero recipient
         * @notice  WHEN: called by the correct user
         * @notice   AND: cap is not exceeded
         * @notice  THEN: tokens are minted
         */

        uint256 balanceBefore = t_.balanceOf(user);
        vm.prank(multisig);
        t_.mint(user, testingAmount);
        uint256 balanceAfter = t_.balanceOf(user);
        assertEq(balanceAfter - balanceBefore, testingAmount);
    }

    function test_mint_wrong_user() public skip(false) {
        /** -------------------------------------------------------
         * @notice Minting by the wrong user
         * --------------------------------------------------------
         * @notice GIVEN: non-zero amount and non-zero recipient
         * @notice  WHEN: called by the wrong user
         * @notice  THEN: access error is thrown
         */

        vm.expectRevert(abi.encodePacked(wrongMultisig));
        vm.prank(user);
        t_.mint(user, 100);
    }

    function test_mint_capped() public skip(false) {
        /** -------------------------------------------------------
         * @notice Minting exceeding cap
         * --------------------------------------------------------
         * @notice GIVEN: mint() is called
         * @notice  WHEN: cap is reached
         * @notice  THEN: error is thrown
         */
        vm.prank(manager);
        t_.init(address(p_), 10 * 10e6);
        vm.prank(multisig);
        vm.expectRevert("ERC20Capped: cap exceeded");
        t_.mint(user, 100);
    }

    function test_burn_happy_path() public skip(false) {
        /** -------------------------------------------------------
         * @notice Burning happy path
         * --------------------------------------------------------
         * @notice GIVEN: non-zero amount
         * @notice  THEN: expected amount is burned
         */
        vm.startPrank(multisig);
        t_.mint(multisig, testingAmount);
        assertEq(t_.totalSupply(), 100 * 10e6);
        assertEq(t_.balanceOf(multisig), testingAmount);
        t_.burn(testingAmount);
        assertEq(t_.balanceOf(multisig), 0);
    }

    function test_burn_wrong_user() public skip(false) {
        /** -------------------------------------------------------
         * @notice Burning by the wrong user
         * --------------------------------------------------------
         * @notice GIVEN: non-zero amount
         * @notice  WHEN: called by the wrong user
         * @notice  THEN: access error is thrown
         */
        vm.expectRevert(abi.encodePacked(wrongMultisig));
        vm.prank(user);
        t_.burn(testingAmount);
    }

    function test_pause_happy_path() public skip(false) {
        /** -------------------------------------------------------
         * @notice Pausing happy path
         * --------------------------------------------------------
         * @notice GIVEN: contract is not paused
         * @notice  WHEN: called by the manager
         * @notice  THEN: contract is paused
         */
        assert(!t_.paused());
        vm.prank(manager);
        t_.pause();
        assert(t_.paused());
    }

    function test_pause_wrong_user() public skip(false) {
        /** -------------------------------------------------------
         * @notice Pausing by the wrong user
         * --------------------------------------------------------
         * @notice GIVEN: contract is not paused
         * @notice  WHEN: called not by manager
         * @notice  THEN: access error is thrown
         */

        vm.expectRevert(abi.encodePacked(wrongManager));
        vm.prank(user);
        t_.pause();
    }

    function test_unpause_happy_path() public skip(false) {
        /** -------------------------------------------------------
         * @notice Unpausing happy path
         * --------------------------------------------------------
         * @notice GIVEN: contract is paused
         * @notice  WHEN: called by the multisig
         * @notice  THEN: contract is unpaused
         */
        vm.prank(manager);
        t_.pause();
        assert(t_.paused());
        vm.prank(multisig);
        t_.unpause();
        assert(!t_.paused());
    }

    function test_unpause_wrong_user() public skip(false) {
        /** -------------------------------------------------------
         * @notice Unpausing by the wrong user
         * --------------------------------------------------------
         * @notice GIVEN: contract is paused
         * @notice  WHEN: called not by multisig
         * @notice  THEN: access error is thrown
         */

        vm.expectRevert(abi.encodePacked(wrongMultisig));
        vm.prank(user);
        t_.unpause();
    }

    /** ----------------------------------
     * ! Helper to test AccessControl
     * ----------------------------------- */

    function getRoleErrorMessage(
        address addr,
        bytes32 role
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "AccessControl: account ",
                    Strings.toHexString(uint160(addr), 20),
                    " is missing role ",
                    Strings.toHexString(uint256(role), 32)
                )
            );
    }

    /** ----------------------------------
     * ! Test contract modifiers
     * ----------------------------------- */

    /**
     * @notice this modifier will skip the test
     */
    modifier skip(bool isSkipped) {
        if (!isSkipped) {
            _;
        }
    }

    /**
     * @notice this modifier will skip the testFail*** tests ONLY
     */
    modifier skipFailing(bool isSkipped) {
        if (isSkipped) {
            require(0 == 1);
        } else {
            _;
        }
    }
}
