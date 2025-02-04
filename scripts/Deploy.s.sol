// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../contracts/Token.sol";
import "../contracts/TokenPeg.sol";
import "../contracts/IBridge.sol";
import "../contracts/Roles.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract Mainnet is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("MAIN_DEPLOYER_PK");
        uint256 rolesManagerPk = vm.envUint("MAIN_ROLES_MANAGER_PK");

        // Get role addresses
        address deployer = vm.envAddress("MAIN_DEPLOYER");
        address rolesManager = vm.envAddress("MAIN_ROLES_MANAGER");
        address tokenContractManager = vm.envAddress(
            "MAIN_TOKEN_CONTRACT_MANAGER"
        );
        address tokenRecoveryManager = vm.envAddress(
            "MAIN_TOKEN_RECOVERY_MANAGER"
        );
        address multisig = vm.envAddress("MAIN_MULTISIG");
        address pegManager = vm.envAddress("MAIN_PEG_MANAGER");
        address bridge = vm.envAddress("MAIN_BRIDGE_ADDRESS");

        // Validate addresses
        require(deployer != address(0), "Invalid deployer address");
        require(rolesManager != address(0), "Invalid roles manager address");
        require(
            tokenContractManager != address(0),
            "Invalid token contract manager"
        );
        require(
            tokenRecoveryManager != address(0),
            "Invalid token recovery manager"
        );
        require(multisig != address(0), "Invalid multisig address");
        require(pegManager != address(0), "Invalid peg manager address");
        require(bridge != address(0), "Invalid bridge address");

        console.log("\nDeploying to mainnet with:");
        console.log("Deployer: %s", deployer);
        console.log("Roles Manager: %s", rolesManager);
        console.log("Token Contract Manager: %s", tokenContractManager);
        console.log("Token Recovery Manager: %s", tokenRecoveryManager);
        console.log("Multisig: %s", multisig);
        console.log("Peg Manager: %s", pegManager);
        console.log("Bridge: %s", bridge);

        vm.startBroadcast(deployerPk);

        // Deploy Token contract
        Token token = new Token(
            rolesManager,
            tokenContractManager,
            tokenRecoveryManager,
            multisig
        );
        console.log("\nToken deployed to: %s", address(token));

        // Deploy TokenPeg contract
        TokenPeg peg = new TokenPeg(
            IBridge(bridge),
            IERC20(address(token)),
            rolesManager,
            pegManager
        );
        console.log("TokenPeg deployed to: %s", address(peg));

        vm.stopBroadcast();

        // Initialize token with peg address using roles manager
        vm.startBroadcast(rolesManagerPk);
        token.init(address(peg));
        vm.stopBroadcast();

        console.log("\nDeployment Complete");
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
    }
}

contract Testnet is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("TEST_DEPLOYER_PK");
        uint256 rolesManagerPk = vm.envUint("TEST_ROLES_MANAGER_PK");

        // Get role addresses
        address deployer = vm.envAddress("TEST_DEPLOYER");
        address rolesManager = vm.envAddress("TEST_ROLES_MANAGER");
        address tokenContractManager = vm.envAddress(
            "TEST_TOKEN_CONTRACT_MANAGER"
        );
        address tokenRecoveryManager = vm.envAddress(
            "TEST_TOKEN_RECOVERY_MANAGER"
        );
        address multisig = vm.envAddress("TEST_MULTISIG");
        address pegManager = vm.envAddress("TEST_PEG_MANAGER");
        address bridge = vm.envAddress("TEST_BRIDGE_ADDRESS");

        console.log("\nDeploying to testnet with:");
        console.log("Deployer: %s", deployer);
        console.log("Roles Manager: %s", rolesManager);
        console.log("Token Contract Manager: %s", tokenContractManager);
        console.log("Token Recovery Manager: %s", tokenRecoveryManager);
        console.log("Multisig: %s", multisig);
        console.log("Peg Manager: %s", pegManager);
        console.log("Bridge: %s", bridge);

        vm.startBroadcast(deployerPk);

        // Deploy Token contract
        Token token = new Token(
            rolesManager,
            tokenContractManager,
            tokenRecoveryManager,
            multisig
        );
        console.log("\nToken deployed to: %s", address(token));

        // Deploy TokenPeg contract
        TokenPeg peg = new TokenPeg(
            IBridge(bridge),
            IERC20(address(token)),
            rolesManager,
            pegManager
        );
        console.log("TokenPeg deployed to: %s", address(peg));

        vm.stopBroadcast();

        // Initialize token with peg address using roles manager
        vm.startBroadcast(rolesManagerPk);
        token.init(address(peg));
        vm.stopBroadcast();

        console.log("\nDeployment Complete");
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
    }
}

contract Production is Script {
    function run() external {
        uint256 pk = vm.envUint("PROD_PK");

        // Get role addresses from env
        address rolesManager = vm.envAddress("ROLES_MANAGER");
        address tokenContractManager = vm.envAddress("TOKEN_CONTRACT_MANAGER");
        address tokenRecoveryManager = vm.envAddress("TOKEN_RECOVERY_MANAGER");
        address multisig = vm.envAddress("MULTISIG");
        address pegManager = vm.envAddress("PEG_MANAGER");
        address bridge = vm.envAddress("BRIDGE_ADDRESS");

        // Validate addresses
        require(rolesManager != address(0), "Invalid roles manager address");
        require(
            tokenContractManager != address(0),
            "Invalid token contract manager address"
        );
        require(
            tokenRecoveryManager != address(0),
            "Invalid token recovery manager address"
        );
        require(multisig != address(0), "Invalid multisig address");
        require(pegManager != address(0), "Invalid peg manager address");
        require(bridge != address(0), "Invalid bridge address");

        console.log("Deploying to production...");
        console.log("Roles Manager: %s", rolesManager);
        console.log("Token Contract Manager: %s", tokenContractManager);
        console.log("Token Recovery Manager: %s", tokenRecoveryManager);
        console.log("Multisig: %s", multisig);
        console.log("Peg Manager: %s", pegManager);
        console.log("Bridge: %s", bridge);

        vm.startBroadcast(pk);

        // Deploy Token contract
        Token token = new Token(
            rolesManager,
            tokenContractManager,
            tokenRecoveryManager,
            multisig
        );
        console.log("Token deployed to: %s", address(token));

        // Deploy TokenPeg contract
        TokenPeg peg = new TokenPeg(
            IBridge(bridge),
            IERC20(address(token)),
            rolesManager,
            pegManager
        );
        console.log("TokenPeg deployed to: %s", address(peg));

        vm.stopBroadcast();

        // Initialize token with peg address using token contract manager
        vm.startBroadcast(tokenContractManager);
        token.init(address(peg));
        vm.stopBroadcast();

        console.log("\nProduction Deployment Complete");
        console.log("Token: %s", address(token));
        console.log("TokenPeg: %s", address(peg));
        console.log("Token initialized with peg: %s", address(peg));
    }
}

// contract Porcini is Script {
//     uint256 deployer_pk = vm.envUint("DEV_PRIVATE_KEY_1");
//     uint256 manager_pk = vm.envUint("DEV_PRIVATE_KEY_2");

//     address minter;
//     address manager = vm.envAddress("DEV_ADDRESS_2");
//     address signer = vm.envAddress("DEV_SIGNER");
//     string uri = vm.envString("DEV_URI");

//     function run() external {
//         vm.startBroadcast(deployer_pk);
//         ProcessedTokens pt_ = new ProcessedTokens(manager);
//         Swappable s_ = new Swappable(manager, signer, address(pt_));

//         minter = address(s_);

//         NFT nft_ = new NFT("NFT", "NFT", manager);
//         NFTProxyMinter nftp_ = new NFTProxyMinter(
//             manager,
//             minter,
//             address(nft_)
//         );

//         SFT sft_ = new SFT(manager, uri);
//         SFTProxyMinter sftp_ = new SFTProxyMinter(
//             manager,
//             minter,
//             address(sft_)
//         );

//         vm.stopBroadcast();
//         console.log("ProcessedTokens address: %s", address(pt_));
//         console.log("Swappable address: %s", address(s_));
//         console.log("NFTProxyMinter address: %s", address(nftp_));
//         console.log("NFT address: %s", address(nft_));
//         console.log("SFTProxyMinter address: %s", address(sftp_));
//         console.log("SFT address: %s", address(sft_));

//         vm.startBroadcast(manager_pk);
//         pt_.grantRole(MINTER, minter);
//         vm.stopBroadcast();

//         console.log("\nSwappable %s is a Minter", minter);
//     }
// }

// contract TRN is Script {
//     address minter;
//     uint256 deployer_pk = vm.envUint("ROOT_DEPLOYER_PRIVATE_KEY");
//     uint256 manager_pk = vm.envUint("ROOT_MANAGER_PRIVATE_KEY");
//     address manager = vm.envAddress("ROOT_MANAGER_ADDRESS");
//     address signer = vm.envAddress("ROOT_SIGNER_ADDRESS");
//     string uri = vm.envString("ROOT_URI");

//     function run() external {
//         vm.startBroadcast(deployer_pk);
//         ProcessedTokens pt_ = new ProcessedTokens(manager);
//         Swappable s_ = new Swappable(manager, signer, address(pt_));

//         minter = address(s_);

//         NFT nft_ = new NFT("NFT", "NFT", manager);
//         NFTProxyMinter nftp_ = new NFTProxyMinter(
//             manager,
//             minter,
//             address(nft_)
//         );

//         SFT sft_ = new SFT(manager, uri);
//         SFTProxyMinter sftp_ = new SFTProxyMinter(
//             manager,
//             minter,
//             address(sft_)
//         );

//         vm.stopBroadcast();
//         console.log("ProcessedTokens address: %s", address(pt_));
//         console.log("Swappable address: %s", address(s_));
//         console.log("NFTProxyMinter address: %s", address(nftp_));
//         console.log("NFT address: %s", address(nft_));
//         console.log("SFTProxyMinter address: %s", address(sftp_));
//         console.log("SFT address: %s", address(sft_));

//         vm.startBroadcast(manager_pk);
//         pt_.grantRole(MINTER, minter);
//         vm.stopBroadcast();

//         console.log("\nSwappable %s is a Minter", minter);
//     }
// }
