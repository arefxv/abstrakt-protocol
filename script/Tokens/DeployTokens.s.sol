// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {AbstraktSmartToken} from "../../src/ProtocolERC20Token/AbstraktSmartToken.sol";
import {AbstraktGovernToken} from "../../src/GovernERC20Token/AbstraktGovernToken.sol";
import {AbstraktGenesisNFT} from "../../src/ERC721NFT/AbstraktGenesisNFT.sol";

contract DeployASTToken is Script {
    function run() external returns (AbstraktSmartToken) {
        return deployASTToken();
    }

    function deployASTToken() public returns (AbstraktSmartToken) {
        vm.startBroadcast();
        AbstraktSmartToken ast = new AbstraktSmartToken();
        vm.stopBroadcast();

        return ast;
    }
}

contract DeployAGTToken is Script {
    function run() external returns (AbstraktGovernToken) {
        return deployAGTToken();
    }

    function deployAGTToken() public returns (AbstraktGovernToken) {
        vm.startBroadcast();
        AbstraktGovernToken agt = new AbstraktGovernToken();
        vm.stopBroadcast();

        return agt;
    }
}

contract DeployNFT is Script {
    string baseURI = "ipfs://QmaeDs5cZAjedXgYrTj2N173ebYdeophHkdDbLb4hHPUJp";

    function run() external returns (AbstraktGenesisNFT) {
        return deployNft();
    }

    function deployNft() public returns (AbstraktGenesisNFT) {
        vm.startBroadcast();
        AbstraktGenesisNFT nft = new AbstraktGenesisNFT(baseURI);
        vm.stopBroadcast();

        return nft;
    }
}
