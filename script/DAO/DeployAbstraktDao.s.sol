// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Timelock} from "../../src/DAO/Timelock.sol";
import {AbstraktDAO} from "../../src/DAO/AbstraktDAO.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAbstraktDao is Script {
    ///@notice deployed AbstraktDAO on Anvil
    address agtCA = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;

    function run() external returns (Timelock, address) {
        return deployAbstraktDao();
    }

    function deployAbstraktDao() public returns (Timelock, address) {
        vm.startBroadcast();
        Timelock timelock = new Timelock();

        bytes memory initialData = abi.encodeWithSelector(AbstraktDAO.initialize.selector, agtCA, timelock);

        AbstraktDAO dao = new AbstraktDAO();
        ERC1967Proxy proxy = new ERC1967Proxy(address(dao), initialData);

        vm.stopBroadcast();

        return (timelock, address(proxy));
    }
}
