// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../contracts/Token.sol";
import "../contracts/TokenPeg.sol";
import "../contracts/IBridge.sol";
import "../contracts/Roles.sol";
import "../contracts/Bridge.sol";

import "forge-std/console.sol";
import "forge-std/Script.sol";

contract Mainnet is Script {
    uint256 deployerPk = vm.envUint("MAIN_DEPLOYER_PK");
    uint256 rolesManagerPk = vm.envUint("MAIN_ROLES_MANAGER_PK");
    uint256 tokenManagerPk = vm.envUint("MAIN_TOKEN_MANAGER_PK");
    uint256 pegManagerPk = vm.envUint("MAIN_PEG_MANAGER_PK");

    address deployer = vm.envAddress("MAIN_DEPLOYER");
    address rolesManager = vm.envAddress("MAIN_ROLES_MANAGER");
    address tokenManager = vm.envAddress("MAIN_TOKEN_MANAGER");
    address recoveryManager = vm.envAddress("MAIN_TOKEN_RECOVERY_MANAGER");
    address pegManager = vm.envAddress("MAIN_PEG_MANAGER");
    address multisig = vm.envAddress("MAIN_MULTISIG");

    function run() external {
        vm.startBroadcast(deployerPk);

        Bridge bridge = new Bridge();
        console.log("\nBridge deployed to: %s", address(bridge));
        console.log("The owner of the Bridge is: %s", deployer);

        Token token = new Token(
            rolesManager,
            tokenManager,
            recoveryManager,
            multisig
        );
        console.log("\nToken deployed to: %s", address(token));
        console.log("The Roles manager is: %s", rolesManager);
        console.log("The manager of the Token is: %s", tokenManager);
        console.log("The recovery manager is: %s", recoveryManager);
        console.log("The multisig of the Token is: %s", multisig);

        TokenPeg peg = new TokenPeg(
            IBridge(bridge),
            IERC20(address(token)),
            rolesManager,
            pegManager
        );
        console.log("\nTokenPeg deployed to: %s", address(peg));
        console.log("The Roles manager of the TokenPeg is: %s", rolesManager);
        console.log("The peg manager of the TokenPeg is: %s", pegManager);
        console.log("Token role set (to store refunds): %s", address(token));

        vm.stopBroadcast();

        /**
         * Setup:
         * 1. Initialize token with peg address
         * 2. Activate bridge
         * 3. Activate TokenPeg deposits
         */

        vm.startBroadcast(deployerPk); // Deployer is the bridge owner
        bridge.setActive(true);
        console.log("Bridge activated");
        vm.stopBroadcast();

        vm.startBroadcast(tokenManagerPk); // Roles manager is the token contract manager
        token.init(address(peg));
        console.log("Token initialized with peg address: %s", address(peg));
        vm.stopBroadcast();

        vm.startBroadcast(pegManagerPk); // Peg manager can activate deposits
        peg.setDepositsActive(true);
        peg.setWithdrawalsActive(true);
        console.log("TokenPeg deposits/withdrawals activated");
        peg.setPalletAddress(address(0x0)); // ! TODO: Correct pallet address must be set
        console.log("Pallet address set to: %s", address(0x0));
        vm.stopBroadcast();

        console.log("\nDeployment Complete");
        console.log("Bridge: %s", address(bridge));
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
    }
}

contract Testnet is Script {
    uint256 deployerPk = vm.envUint("TEST_DEPLOYER_PK");
    uint256 rolesManagerPk = vm.envUint("TEST_ROLES_MANAGER_PK");
    uint256 tokenManagerPk = vm.envUint("TEST_TOKEN_MANAGER_PK");
    uint256 pegManagerPk = vm.envUint("TEST_PEG_MANAGER_PK");

    address deployer = vm.envAddress("TEST_DEPLOYER");
    address rolesManager = vm.envAddress("TEST_ROLES_MANAGER");
    address tokenManager = vm.envAddress("TEST_TOKEN_MANAGER");
    address recoveryManager = vm.envAddress("TEST_TOKEN_RECOVERY_MANAGER");
    address pegManager = vm.envAddress("TEST_PEG_MANAGER");
    address multisig = vm.envAddress("TEST_MULTISIG");

    function run() external {
        vm.startBroadcast(deployerPk);

        Bridge bridge = new Bridge();
        console.log("\nBridge deployed to: %s", address(bridge));
        console.log("The owner of the Bridge is: %s", deployer);

        Token token = new Token(
            rolesManager,
            tokenManager,
            recoveryManager,
            multisig
        );
        console.log("\nToken deployed to: %s", address(token));
        console.log("The Roles manager is: %s", rolesManager);
        console.log("The manager of the Token is: %s", tokenManager);
        console.log("The recovery manager is: %s", recoveryManager);
        console.log("The multisig of the Token is: %s", multisig);

        TokenPeg peg = new TokenPeg(
            IBridge(bridge),
            IERC20(address(token)),
            rolesManager,
            pegManager
        );
        console.log("\nTokenPeg deployed to: %s", address(peg));
        console.log("The Roles manager of the TokenPeg is: %s", rolesManager);
        console.log("The peg manager of the TokenPeg is: %s", pegManager);
        console.log("Token role set (to store refunds): %s", address(token));

        vm.stopBroadcast();

        /**
         * Setup:
         * 1. Initialize token with peg address
         * 2. Activate bridge
         * 3. Activate TokenPeg deposits
         */

        vm.startBroadcast(deployerPk); // Deployer is the bridge owner
        bridge.setActive(true);
        console.log("Bridge activated");
        vm.stopBroadcast();

        vm.startBroadcast(tokenManagerPk); // Roles manager is the token contract manager
        token.init(address(peg));
        console.log("Token initialized with peg address: %s", address(peg));
        vm.stopBroadcast();

        vm.startBroadcast(pegManagerPk); // Peg manager can activate deposits
        peg.setDepositsActive(true);
        peg.setWithdrawalsActive(true);
        console.log("TokenPeg deposits/withdrawals activated");
        peg.setPalletAddress(address(0x0)); // ! TODO: Correct pallet address must be set
        console.log("Pallet address set to: %s", address(0x0));
        vm.stopBroadcast();

        console.log("\nDeployment Complete");
        console.log("Bridge: %s", address(bridge));
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
    }
}

contract TokenOnly is Script {
    uint256 deployerPk = vm.envUint("TEST_DEPLOYER_PK");
    uint256 rolesManagerPk = vm.envUint("TEST_ROLES_MANAGER_PK");
    uint256 tokenManagerPk = vm.envUint("TEST_TOKEN_MANAGER_PK");
    uint256 pegManagerPk = vm.envUint("TEST_PEG_MANAGER_PK");

    address deployer = vm.envAddress("TEST_DEPLOYER");
    address rolesManager = vm.envAddress("TEST_ROLES_MANAGER");
    address tokenManager = vm.envAddress("TEST_TOKEN_MANAGER");
    address recoveryManager = vm.envAddress("TEST_TOKEN_RECOVERY_MANAGER");
    address pegManager = vm.envAddress("TEST_PEG_MANAGER");

    address multisig = vm.envAddress("TEST_MULTISIG");
    address peg = vm.envAddress("TEST_PEG");

    function run() external {
        vm.startBroadcast(deployerPk);

        Token token = new Token(
            rolesManager,
            tokenManager,
            recoveryManager,
            multisig
        );
        console.log("\nToken deployed to: %s", address(token));
        console.log("The Roles manager is: %s", rolesManager);
        console.log("The manager of the Token is: %s", tokenManager);
        console.log("The recovery manager is: %s", recoveryManager);
        console.log("The multisig of the Token is: %s", multisig);

        vm.stopBroadcast();

        /**
         * Setup:
         * 1. Initialize token with peg address
         * 2. Activate bridge
         * 3. Activate TokenPeg deposits
         */

        vm.startBroadcast(tokenManagerPk); // Roles manager is the token contract manager
        token.init(address(peg));
        console.log("Token initialized with peg address: %s", address(peg));
        vm.stopBroadcast();

        console.log("\nDeployment Complete");
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
    }
}
