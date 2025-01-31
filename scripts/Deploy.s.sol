// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "../contracts/ThinkTokenPeg.sol";
import "../contracts/ThinkToken.sol";
import "../contracts/Bridge.sol";
import "../contracts/IBridge.sol";

import "forge-std/console.sol";
import "forge-std/Script.sol";

contract Locally is Script {
    function run() external {
        uint256 pk = vm.envUint("LOCAL_PK");

        address manager = vm.envAddress("DEV_MANAGER");
        address multisig = vm.envAddress("DEV_MANAGER"); // For testing they are the same
        console.log("Manager address: %s", manager);
        console.log("Multisig address: %s", multisig);

        vm.startBroadcast(pk);

        Bridge bridge_ = new Bridge();
        ThinkToken rt_ = new ThinkToken(manager, multisig);
        ThinkTokenPeg peg_ = new ThinkTokenPeg(IBridge(bridge_), address(rt_));

        bridge_.setActive(true);
        peg_.setDepositsActive(true);

        vm.stopBroadcast();

        vm.startBroadcast(manager);
        rt_.init(address(peg_));
        vm.stopBroadcast();

        console.log("Bridge address: %s", address(bridge_));
        console.log("ThinkTokenPeg address: %s", address(peg_));
        console.log("ThinkToken address: %s", address(rt_));
    }
}

contract Testnet is Script {
    function run() external {
        uint256 pk = vm.envUint("DEV_PK");
        uint256 manager_pk = vm.envUint("DEV_MANAGER_PK");

        address manager = vm.envAddress("DEV_MANAGER");
        address multisig = vm.envAddress("DEV_MANAGER"); // For testing they are the same
        console.log("Manager address: %s", manager);
        console.log("Multisig address: %s", multisig);

        vm.startBroadcast(pk);

        Bridge bridge_ = new Bridge();
        ThinkToken rt_ = new ThinkToken(manager, multisig);
        ThinkTokenPeg peg_ = new ThinkTokenPeg(IBridge(bridge_), address(rt_));

        bridge_.setActive(true);
        peg_.setDepositsActive(true);

        vm.stopBroadcast();

        vm.startBroadcast(manager_pk);
        rt_.init(address(peg_));
        vm.stopBroadcast();

        console.log("Bridge address: %s", address(bridge_));
        console.log("ThinkTokenPeg address: %s", address(peg_));
        console.log("ThinkToken address: %s", address(rt_));
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
