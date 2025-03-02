// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {AbstraktWalletEngine} from "../../src/AA/AbstraktWalletEngine.sol";
import {AAHelperConfig, CodeConstants} from "../HelperConfig.s.sol";

contract DeployAbstraktWalletEngine is Script {
    function run() external returns (AbstraktWalletEngine, AAHelperConfig) {
        return deployAbstraktWalletEngine();
    }

    function deployAbstraktWalletEngine() public returns (AbstraktWalletEngine, AAHelperConfig) {
        AAHelperConfig helperConfig = new AAHelperConfig();
        AAHelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        AbstraktWalletEngine walletEngine = new AbstraktWalletEngine(config.entryPoint);
        walletEngine.transferOwnership(config.account);
        vm.stopBroadcast();

        return (walletEngine, helperConfig);
    }
}
