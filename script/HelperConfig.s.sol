// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../src/Helper/mock/LinkToken.sol";
import {EntryPoint} from "@AA/core/EntryPoint.sol";
import {MockV3Aggregator} from "@chainlink-brownie/src/v0.8/tests/MockV3Aggregator.sol";
import {VRFCoordinatorV2Mock} from "@chainlink-brownie/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink-brownie/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ERC20Mock} from "script/mock/ERC20Mock.sol";

/**
 * @title CodeConstants
 * @dev A contract containing all the important constants and configuration data required for various networks,
 * including chain identifiers, VRF configurations, price feeds, and more
 * These constants are crucial for deploying and interacting with smart contracts on different Ethereum-like networks
 * The contract is meant to be inherited by other helper contracts to provide reusable constants and settings
 *
 * @author ArefXV
 */
abstract contract CodeConstants {
    // Define common error types
    error HelperConfig__InvalidChainId(uint256);

    // Network specific constant addresses and settings
    address public constant ACCOUNT = 0x4D49400f047E66f72699C31F25483d8039B0351d;

    address public constant ANVIL_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // ChainLink specific constants: Gas lanes, VRF coordinator addresses, LINK tokens, etc
    bytes32 public constant ETH_MAINNET_GAS_LANE = 0x3fd2fec10d06ee8f65e7f2e95f5c56511359ece3f33960ad8a866ae24a8ff10b;
    bytes32 public constant ETH_BASE_GAS_LANE = 0xdc2f87677b01473c763cb0aee938ed3341512f6057324a584e5944e786144d70;
    bytes32 public constant ETH_SEPOLIA_GAS_LANE = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    address public constant ETH_MAINNET_VRF_COORDINATOR = 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a;
    address public constant ETH_BASE_VRF_COORDINATOR = 0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634;
    address public constant ETH_SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;

    address public constant ETH_MAINNET_LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address public constant ETH_BASE_LINK_ADDRESS = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;
    address public constant ETH_SEPOLIA_LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    address public constant ENTRY_POINT = 0x0576a174D229E3cFA37253523E645A78A0C91B57;

    address public constant ETH_MAINNET_WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant ETH_BASE_WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
    address public constant ETH_SEPOLIA_WETH_ADDRESS = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;

    address public constant ETH_MAINNET_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant ETH_BASE_PRICE_FEED = 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70;
    address public constant ETH_SEPOLIA_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    // chain IDs
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant ETH_BASE_CHAIN_ID = 8453;

    // Default contract settings
    uint256 public constant AUTO_UPDATE_INTERVAL = 60;
    uint256 public constant SUB_ID = 0;
    uint256 public constant RAFFLE_ENTRANCE_FEE = 0.01 ether;
    uint32 public constant CALLBACK_GAS_LIMIT = 500000;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 3000e8;
}

/**
 * @title LuckyHelperConfig
 * @dev This contract is responsible for managing the configuration settings for different networks and setting up VRF (Verifiable Random Function) services
 * It contains methods to fetch configurations based on the current network and provides the necessary setup for each network (Mainnet, Sepolia, Base, and Anvil)
 * The contract ensures that the appropriate VRF coordinator, LINK token, and network-specific settings are available to interact with the raffle system
 * It also manages the local configuration for the Anvil network, ensuring that mock services are used when necessary for local testing
 *
 * @author ArefXV
 */
contract LuckyHelperConfig is Script, CodeConstants {
    /**
     * @dev A struct that contains all necessary configuration data for a given network
     * This includes the subscription ID for VRF, gas lane, auto-update interval, entrance fee, callback gas limit, VRF coordinator address,
     * LINK token address, and the account address for interacting with the network
     */
    struct NetworkConfig {
        uint256 subscriptionId; // Subscription ID for ChainLink VRF service
        bytes32 gasLane; // The gas lane to use for VRF requests
        uint256 autoUpdateInterval; // Interval at which to update configurations
        uint256 entranceFee; // Fee to participate in the raffle
        uint32 callbackGasLimit; // Gas limit for the callback function after VRF response
        address vrfCoordinatorV2_5; // VRF Coordinator address for the network
        address linkToken; // Address of the LINK token contract for the network
            // address account; // Account address for interacting with the network
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        // Populate network configurations for Mainnet, Sepolia, and Base
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ETH_BASE_CHAIN_ID] = getEthBaseConfig();
    }

    /**
     * @dev Fetches the current network configuration based on the current chain ID
     * If a configuration for the current chain ID doesn't exist, an error is thrown
     * @return NetworkConfig The configuration for the current network
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    /**
     * @dev Fetches the network configuration by chain ID
     * If the network doesn't have a configuration, it reverts with an invalid chain ID error
     * @param chainId The chain ID for the desired network
     * @return NetworkConfig The configuration for the specified network
     */
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    /**
     * @dev Fetches the configuration for the Ethereum Mainnet
     * @return NetworkConfig The configuration for Ethereum Mainnet
     */
    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: SUB_ID, // ChainLink subscription ID
            gasLane: ETH_MAINNET_GAS_LANE, // Mainnet gas lane
            autoUpdateInterval: AUTO_UPDATE_INTERVAL, // Auto update interval
            entranceFee: RAFFLE_ENTRANCE_FEE, // Raffle entrance fee
            callbackGasLimit: CALLBACK_GAS_LIMIT, // Callback gas limit
            vrfCoordinatorV2_5: ETH_MAINNET_VRF_COORDINATOR, // VRF Coordinator address for Mainnet
            linkToken: ETH_MAINNET_LINK_ADDRESS // LINK token address for Mainnet
                // account: ACCOUNT // The account address interacting with the network
        });
    }

    /**
     * @dev Fetches the configuration for the Ethereum Base Mainnet
     * @return NetworkConfig The configuration for Ethereum Base Mainnet
     */
    function getEthBaseConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: SUB_ID, // create 11
            gasLane: ETH_BASE_GAS_LANE,
            autoUpdateInterval: AUTO_UPDATE_INTERVAL, // 1 min
            entranceFee: RAFFLE_ENTRANCE_FEE,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            vrfCoordinatorV2_5: ETH_BASE_VRF_COORDINATOR,
            linkToken: ETH_BASE_LINK_ADDRESS
        });
        // account: ACCOUNT
    }

    /**
     * @dev Fetches the configuration for the Ethereum Sepolia
     * @return NetworkConfig The configuration for Ethereum Sepolia
     */
    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            subscriptionId: SUB_ID,
            gasLane: ETH_SEPOLIA_GAS_LANE,
            autoUpdateInterval: AUTO_UPDATE_INTERVAL,
            entranceFee: RAFFLE_ENTRANCE_FEE,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            vrfCoordinatorV2_5: ETH_SEPOLIA_VRF_COORDINATOR,
            linkToken: ETH_SEPOLIA_LINK_ADDRESS
        });
        // account: ACCOUNT
    }

    /**
     * @dev Creates or retrieves the local network configuration for Anvil testing
     * This function sets up a mock VRF coordinator and LINK token for local testing and development
     * @return NetworkConfig The configuration for the local Anvil network
     */
    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2Mock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken mockLink = new LinkToken();
        uint256 subscriptionId = vrfCoordinatorV2Mock.createSubscription();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: subscriptionId,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            autoUpdateInterval: 60,
            entranceFee: 0.01 ether,
            callbackGasLimit: 500000,
            vrfCoordinatorV2_5: address(vrfCoordinatorV2Mock),
            linkToken: address(mockLink)
        });
        // account: ANVIL_DEFAULT_SENDER

        // vm.deal(localNetworkConfig.account, 100 ether);
        return localNetworkConfig;
    }
}

contract AAHelperConfig is Script, CodeConstants {
    /**
     * @dev Struct to store configuration data for a network
     * @param account Address of the account associated with the network
     * @param linkToken Address of the LINK token associated with the network
     * @param entryPoint Address of the entry point contract
     */
    struct NetworkConfig {
        address account;
        address linkToken;
        address entryPoint;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ETH_BASE_CHAIN_ID] = getEthBaseConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].entryPoint != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: ACCOUNT, linkToken: ETH_MAINNET_LINK_ADDRESS, entryPoint: ENTRY_POINT});
    }

    function getEthBaseConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: ACCOUNT, linkToken: ETH_BASE_LINK_ADDRESS, entryPoint: ENTRY_POINT});
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({account: ACCOUNT, linkToken: ETH_SEPOLIA_LINK_ADDRESS, entryPoint: ENTRY_POINT});
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.entryPoint != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_SENDER);
        EntryPoint entryPoint = new EntryPoint();
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig =
            NetworkConfig({account: ANVIL_DEFAULT_SENDER, linkToken: address(link), entryPoint: address(entryPoint)});

        return localNetworkConfig;
    }
}

contract XVFiHelperConfig is Script, CodeConstants {
    /**
     * @dev Struct to store configuration data for a network
     * @param deployerKey The private key of the deployer for the network
     * @param weth Address of the WETH token associated with the network
     * @param wethUsdPriceFeed Address of the WETH/USD price feed contract
     */
    struct NetworkConfig {
        address weth;
        address wethUsdPriceFeed;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ETH_BASE_CHAIN_ID] = getEthBaseConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].wethUsdPriceFeed != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({weth: ETH_MAINNET_WETH_ADDRESS, wethUsdPriceFeed: ETH_MAINNET_PRICE_FEED});
    }

    function getEthBaseConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({weth: ETH_BASE_PRICE_FEED, wethUsdPriceFeed: ETH_MAINNET_PRICE_FEED});
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({weth: ETH_SEPOLIA_WETH_ADDRESS, wethUsdPriceFeed: ETH_SEPOLIA_PRICE_FEED});
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.wethUsdPriceFeed != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 3000e8);
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({weth: address(wethMock), wethUsdPriceFeed: address(ethUsdPriceFeed)});

        return localNetworkConfig;
    }
}
