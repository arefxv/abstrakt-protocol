// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LuckyHelperConfig} from "../HelperConfig.s.sol";
import {CreateSubscription, AddConsumer, FundSubscription} from "./Interactions.s.sol";
import {LuckyStrakt} from "../../src/Lottery/LuckyStrakt.sol";
import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IAbstraktGenesisNFT} from "../../src/Interface/IAbstraktGenesisNFT.sol";

contract DeployLuckyStrakt is Script {
    ///@notice deployed AbstraktGenesisNFT on Anvil
    address nftCA = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;

    function run() external returns (LuckyStrakt, LuckyHelperConfig) {
        LuckyHelperConfig helperConfig = new LuckyHelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        LuckyHelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinatorV2_5, config.subscriptionId, config.linkToken);

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast();
        LuckyStrakt lottery = new LuckyStrakt(
            config.entranceFee,
            config.autoUpdateInterval,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5,
            IAbstraktGenesisNFT(nftCA)
        );

        vm.stopBroadcast();

        addConsumer.addConsumer(address(lottery), config.vrfCoordinatorV2_5, config.subscriptionId);

        return (lottery, helperConfig);
    }
}
