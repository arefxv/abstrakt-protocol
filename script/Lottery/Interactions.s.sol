// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LuckyHelperConfig, CodeConstants} from "../HelperConfig.s.sol";
import {LuckyStrakt} from "../../src/Lottery/LuckyStrakt.sol";
import {DevOpsTools} from "../../lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../../src/Helper/mock/LinkToken.sol";
import {VRFCoordinatorV2Mock} from "@chainlink-brownie/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscription(address vrfCoordinatorV2_5) public returns (uint256, address) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();

        return (subId, vrfCoordinatorV2_5);
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        LuckyHelperConfig helperConfig = new LuckyHelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        // address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDepolyed) public {
        LuckyHelperConfig helperConfig = new LuckyHelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;
        // address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDepolyed, vrfCoordinator, subId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("LuckyStrakt", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint96 public constant FUND_AMOUNT = 5 ether;

    function fundSubscription(address vrfCoordinatorV2_5, uint256 subId, address linkToken) public {
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function fundSubscriptionUsingConfig() public {
        LuckyHelperConfig helperConfig = new LuckyHelperConfig();

        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().linkToken;
        // address account = helperConfig.getConfig().account;

        if (subId == 0) {
            CreateSubscription createSubscriptionId = new CreateSubscription();
            (uint256 updatedSubId, address updatedVrfV2) = createSubscriptionId.run();
            subId = updatedSubId;
            vrfCoordinatorV2_5 = updatedVrfV2;
        }

        fundSubscription(vrfCoordinatorV2_5, subId, linkToken);
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}
