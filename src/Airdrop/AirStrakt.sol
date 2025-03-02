// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20, SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin-contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin-contracts/utils/cryptography/MerkleProof.sol";
import {Checkers} from "../Helper/Checkers.sol";

/**
 * @title AirStrakt
 * @author ArefXV https://github.com/arefxv
 * @dev A secure airdrop distribution system combining Merkle proofs and EIP-712 signatures
 * @notice Implements gas-efficient airdrop claims with replay protection and verification safeguards
 * Features include:
 * - Merkle tree verification for eligibility proofs
 * - EIP-712 typed structured data signatures
 * - Non-reentrancy protection
 * - ERC20 token safety handling
 * - Address and amount validation checks
 */
contract AirStrakt is EIP712, ReentrancyGuard, Checkers {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MerkleProof for bytes32;

    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/

    error AirStrakt__AlreadyClaimed();
    error AirStrakt__InvalidSignature();
    error AirStrakt__InvalidProof();

    /*/////////////////////////////////////////////////////////////
                                TYPES
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev Struct representing an airdrop claim request
     * @param account Address eligible for the airdrop
     * @param amount Token amount to be claimed
     */
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    /*/////////////////////////////////////////////////////////////
                            STATE VARIABLES
    /////////////////////////////////////////////////////////////*/

    bytes32 private immutable i_merkleRoot;
    bytes32 private immutable i_messageTypeHash;

    mapping(address => bool) s_hasClaimed;
    mapping(address => uint256) s_claimerNonce;

    IERC20 private immutable i_airdropToken;

    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a successful airdrop claim occurs
     * @param user Address that claimed tokens
     * @param value Amount of tokens claimed
     */
    event AirdropClaimed(address indexed user, uint256 indexed value);

    /*/////////////////////////////////////////////////////////////
                                FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the airdrop contract
     * @dev Sets up EIP-712 domain separator and initial configuration
     * @param merkleRoot Root hash of the Merkle eligibility tree
     * @param airdropToken ERC20 token contract to distribute
     */
    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("AirStrakt", "1.0.0") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
        i_messageTypeHash = keccak256("AirdropClaim(address account, uint256 amount)");
    }

    /*/////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates EIP-712 message hash for claim signing
     * @dev Includes nonce to prevent signature replay attacks
     * @param account Claimant address
     * @param amount Claim amount
     * @return bytes32 EIP-712 compliant message hash
     */
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(i_messageTypeHash, AirdropClaim({account: account, amount: amount}), s_claimerNonce[account])
            )
        );
    }

    /*/////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes airdrop claim with multiple verification layers
     * @dev Combines Merkle proof verification and EIP-712 signature validation
     * @param account Address making the claim
     * @param amount Token amount to claim
     * @param merkleProof Array of Merkle proof elements
     * @param v ECDSA signature component
     * @param r ECDSA signature component
     * @param s ECDSA signature component
     * Requirements:
     * - Account must not have previously claimed
     * - Signature must match claim parameters
     * - Merkle proof must verify against contract's root
     */
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
        nonReentrant
        moreThanZero(amount)
        nonAddressZero(account)
    {
        _validateClaim(account, amount, merkleProof, v, r, s);

        s_hasClaimed[account] = true;
        s_claimerNonce[account]++;
        emit AirdropClaimed(account, amount);

        i_airdropToken.safeTransfer(account, amount);
    }

    /*/////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal validation logic for airdrop claims
     * @param account Address making the claim
     * @param amount Token amount to claim
     * @param merkleProof Array of Merkle proof elements
     * @param v ECDSA signature component
     * @param r ECDSA signature component
     * @param s ECDSA signature component
     */
    function _validateClaim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        if (s_hasClaimed[account]) {
            revert AirStrakt__AlreadyClaimed();
        }

        bytes32 digest = getMessageHash(account, amount);
        if (ECDSA.recover(digest, v, r, s) != account) {
            revert AirStrakt__InvalidSignature();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert AirStrakt__InvalidProof();
        }
    }

    /*/////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function getRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getMessageTypeHash() external view returns (bytes32) {
        return i_messageTypeHash;
    }

    function getUserClaimStatus(address user) external view returns (bool) {
        return s_hasClaimed[user];
    }

    function getUserNonce(address user) external view returns (uint256) {
        return s_claimerNonce[user];
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }
}
