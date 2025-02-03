// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../contracts/ThinkToken.sol";
import "../contracts/ThinkTokenPeg.sol";
import "../contracts/Bridge.sol";
import "../contracts/IBridge.sol";

import "forge-std/console.sol";
import "forge-std/Script.sol";

contract Locally is Script {
    function run() external {
        uint256 pk = vm.envUint("LOCAL_PK");
        address manager = vm.envAddress("DEV_MANAGER");
        address multisig = vm.envAddress("DEV_MULTISIG");
        address peg = vm.envAddress("DEV_PEG");

        console.log("Manager address: %s", manager);
        console.log("Multisig address: %s", multisig);
        console.log("Peg address: %s", peg);

        vm.startBroadcast(pk);

        // Deploy ThinkToken
        ThinkToken token = new ThinkToken(manager, multisig);
        console.log("ThinkToken deployed to: %s", address(token));

        // Initialize with peg address
        vm.stopBroadcast();
        vm.startBroadcast(manager);
        token.init(peg);
        vm.stopBroadcast();

        console.log("Deployment complete");
        console.log("Token initialized with peg: %s", peg);
        console.log("Manager role granted to: %s", manager);
        console.log("Multisig role granted to: %s", multisig);
    }
}

contract Testnet is Script {
    function run() external {
        uint256 pk = vm.envUint("DEV_PK");
        uint256 manager_pk = vm.envUint("DEV_MANAGER_PK");

        address manager = vm.envAddress("DEV_MANAGER");
        address multisig = vm.envAddress("DEV_MULTISIG");
        address peg = vm.envAddress("DEV_PEG");

        console.log("Manager address: %s", manager);
        console.log("Multisig address: %s", multisig);
        console.log("Peg address: %s", peg);

        vm.startBroadcast(pk);

        // Deploy ThinkToken
        ThinkToken token = new ThinkToken(manager, multisig);
        console.log("ThinkToken deployed to: %s", address(token));

        vm.stopBroadcast();

        // Initialize with peg address using manager account
        vm.startBroadcast(manager_pk);
        token.init(peg);
        vm.stopBroadcast();

        console.log("Deployment complete");
        console.log("Token initialized with peg: %s", peg);
        console.log("Manager role granted to: %s", manager);
        console.log("Multisig role granted to: %s", multisig);
    }
}

contract Production is Script {
    function run() external {
        uint256 pk = vm.envUint("PROD_PK");
        uint256 manager_pk = vm.envUint("PROD_MANAGER_PK");

        address manager = vm.envAddress("PROD_MANAGER");
        address multisig = vm.envAddress("PROD_MULTISIG");
        address peg = vm.envAddress("PROD_PEG");

        require(manager != address(0), "Invalid manager address");
        require(multisig != address(0), "Invalid multisig address");
        require(peg != address(0), "Invalid peg address");

        console.log("Manager address: %s", manager);
        console.log("Multisig address: %s", multisig);
        console.log("Peg address: %s", peg);

        vm.startBroadcast(pk);

        // Deploy ThinkToken
        ThinkToken token = new ThinkToken(manager, multisig);
        console.log("ThinkToken deployed to: %s", address(token));

        vm.stopBroadcast();

        // Initialize with peg address using manager account
        vm.startBroadcast(manager_pk);
        token.init(peg);
        vm.stopBroadcast();

        console.log("Deployment complete");
        console.log("Token initialized with peg: %s", peg);
        console.log("Manager role granted to: %s", manager);
        console.log("Multisig role granted to: %s", multisig);
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
