// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {AirStrakt} from "../../src/Airdrop/AirStrakt.sol";
import {AbstraktSmartToken} from "../../src/ProtocolERC20Token/AbstraktSmartToken.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract DeployAirStrakt is Script {
    bytes32 public ROOT = 0x93b6fb3dd0d6d9e58a58b70948ebe06ba037324349d73957e94723efd412c124;
    uint256 public TRANSFER_AMOUNT = 100e18 * 10;

    ///@notice deployed AbstraktSmartToken on Anvil
    address astCA = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    AbstraktSmartToken ast;

    function run() external returns (AirStrakt) {
        return deployAirStrakt();
    }

    function deployAirStrakt() public returns (AirStrakt) {
        vm.startBroadcast();
        AirStrakt airdrop = new AirStrakt(ROOT, IERC20(astCA));

        ast = AbstraktSmartToken(astCA);
        ast.mint(ast.owner(), TRANSFER_AMOUNT);
        IERC20(ast).transfer(address(airdrop), TRANSFER_AMOUNT);
        vm.stopBroadcast();

        return airdrop;
    }
}
