// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TimelockControllerUpgradeable} from "@openzeppelin-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Timelock is Initializable, UUPSUpgradeable, TimelockControllerUpgradeable {
    function initialize(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        public
        override
        initializer
    {
        __TimelockController_init(minDelay, proposers, executors, admin);
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
