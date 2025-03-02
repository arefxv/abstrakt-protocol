//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {XVFi} from "../../src/DeFi/Ethereum/XVFi.sol";
import {AbstraktSmartToken} from "../../src/ProtocolERC20Token/AbstraktSmartToken.sol";
import {AbstraktGovernToken} from "../../src/GovernERC20Token/AbstraktGovernToken.sol";
import {AbstraktGenesisNFT} from "../../src/ERC721NFT/AbstraktGenesisNFT.sol";
import {XVFiHelperConfig, CodeConstants} from "../HelperConfig.s.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEthXVFi is Script {
    address tokenAddress;
    address priceFeedAddress;

    ///@notice contreacts deployed on Anvil
    address astCA = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address agtCA = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address nftCA = 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9;

    function run() external returns (XVFiHelperConfig, address) {
        return deployEthXVFi();
    }

    function deployEthXVFi() public returns (XVFiHelperConfig, address) {
        XVFiHelperConfig helperConfig = new XVFiHelperConfig();

        (address weth, address wethUsdPriceFeed) = helperConfig.localNetworkConfig();

        tokenAddress = weth;
        priceFeedAddress = wethUsdPriceFeed;

        vm.startBroadcast();

        bytes memory initializeData =
            abi.encodeWithSelector(XVFi.initialize.selector, tokenAddress, priceFeedAddress, astCA, agtCA, nftCA);
        XVFi xvFi = new XVFi();

        ERC1967Proxy proxy = new ERC1967Proxy(address(xvFi), initializeData);
        vm.stopBroadcast();

        return (helperConfig, address(proxy));
    }
}
