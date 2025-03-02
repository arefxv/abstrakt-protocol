// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SettingsStorage is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    mapping(bytes32 => uint256) private s_settings;

    event SettingUpdated(bytes32 indexed key, uint256 value);

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function storeSetting(bytes32 key, uint256 value) external onlyOwner {
        s_settings[key] = value;
        emit SettingUpdated(key, value);
    }

    function settingExists(bytes32 key) external view returns (bool) {
        return s_settings[key] != 0;
    }

    function getSetting(bytes32 key) external view returns (uint256) {
        return s_settings[key];
    }
}
