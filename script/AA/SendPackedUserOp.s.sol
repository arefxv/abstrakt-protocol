// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@AA/interfaces/PackedUserOperation.sol";
import {AAHelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@AA/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AbstraktWalletEngine} from "src/AA/AbstraktWalletEngine.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 *  @title SendPackedUserOperation
 *  @notice Script for sending a packed user operation via an EntryPoint contract
 *  @dev This script demonstrates how to generate, sign, and broadcast a user operation
 * using account abstraction principles. It supports local and live chain deployments
 */
contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    /// @notice Default private key for Anvil's local test network
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    /// @notice Chain ID for local testing (Anvil)
    uint256 constant LOCAL_CHAIN_ID = 31337;

    /**
     * @notice Entry point for the script execution
     * @dev Sets up configurations, generates a signed user operation, and broadcasts it to the EntryPoint
     */
    function run() public {
        AAHelperConfig helperConfig = new AAHelperConfig();
        address spender = 0x4D49400f047E66f72699C31F25483d8039B0351d;
        address dest = helperConfig.getConfig().linkToken;
        address abstraktWalletEngineAddress =
            DevOpsTools.get_most_recent_deployment("AbstraktWalletEngine", block.chainid);
        uint256 value = 0;

        bytes memory funcData = abi.encodeWithSelector(IERC20.approve.selector, spender, 1e18);

        bytes memory executeCalldata =
            abi.encodeWithSelector(AbstraktWalletEngine.execute.selector, dest, value, funcData);

        PackedUserOperation memory userOp =
            generateSignedUserOperation(executeCalldata, helperConfig.getConfig(), abstraktWalletEngineAddress);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startBroadcast();
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(helperConfig.getConfig().account));
        vm.stopBroadcast();
    }

    /**
     * @notice Generates and signs a packed user operation
     * @param callData The encoded function call data for the user operation
     * @param config The network configuration for the target deployment
     * @param abstraktWalletEngine The address of the abstrakt eallet enginecontract
     * @return A fully signed and prepared `PackedUserOperation`
     */
    function generateSignedUserOperation(
        bytes memory callData,
        AAHelperConfig.NetworkConfig memory config,
        address abstraktWalletEngine
    ) public view returns (PackedUserOperation memory) {
        //1. generate unsigned data
        uint256 nonce = vm.getNonce(abstraktWalletEngine) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, abstraktWalletEngine, nonce);

        //2. get userOp hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //3. sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == LOCAL_CHAIN_ID) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    /**
     *
     * @notice Generates an unsigned user operation
     * @param callData The encoded function call data for the operation
     * @param sender The address of the sender account
     * @param nonce The nonce value for the operation
     * @return An unsigned `PackedUserOperation` struct
     */
    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
