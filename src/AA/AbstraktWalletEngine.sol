// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IEntryPoint} from "@AA/interfaces/IEntryPoint.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {PackedUserOperation} from "@AA/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "@AA/core/Helpers.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";

/**
 * @title AbstraktWalletEngine
 * @author ArefXV https://github.com/arefxv
 * @dev Smart contract wallet engine with Account Abstraction (ERC-4337) support, social recovery,
 * WebAuthn integration, and security features including guardians and wallet freezing.
 * Inherits from OpenZeppelin's Ownable and ReentrancyGuard for access control and protection against reentrancy attacks.
 * @notice This contract handles wallet operations including transaction execution, signature validation,
 * guardian management, and emergency recovery features.
 */
contract AbstraktWalletEngine is Ownable, ReentrancyGuard {
    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/
    error AbstraktWalletEngine__NotFromEntryPoint();
    error AbstraktWalletEngine__NotFromEntryPointOrOwner();
    error AbstraktWalletEngine__TransferFailed(bytes);
    error AbstraktWalletEngine__CallFailed();
    error AbstraktWalletEngine__InvalidInputLengths();
    error AbstraktWalletEngine__InvalidSignature();
    error AbstraktWalletEngine__NotGuardian();
    error AbstraktWalletEngine__WalletFrozen();
    error AbstraktWalletEngine__GuardianAlreadyAdded();

    /*/////////////////////////////////////////////////////////////
                            STATE VARIABLES
    /////////////////////////////////////////////////////////////*/

    uint8 private constant GUARDIAN_THRESHOLD = 2;

    /// @notice EntryPoint contract reference for ERC-4337 compliance
    IEntryPoint private immutable i_entryPoint;

    /// @dev Mapping of Google IDs to wallet addresses
    mapping(bytes32 => address) private s_googleIdToWallet;
    /// @dev Mapping of wallet addresses to WebAuthn public key hashes
    mapping(address => bytes32) private s_webAuthnPubKeys;
    /// @dev Mapping of wallet addresses to their guardian lists
    mapping(address => address[]) private s_guardians;
    /// @dev Mapping tracking number of guardian approvals per wallet
    mapping(address => uint256) private s_guardianApprovals;
    /// @dev Mapping tracking frozen wallet status
    mapping(address => bool) private s_frozenWallets;
    /// @dev Mapping tracking guardian status of addresses
    mapping(address => bool) private s_isGuardian;

    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/

    event UserVerified(address indexed user, bytes32 indexed googleId);
    event WalletFrozen(address wallet);
    event WalletUnfrozen(address wallet);

    /*/////////////////////////////////////////////////////////////
                                MODIFIERS
    /////////////////////////////////////////////////////////////*/

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert AbstraktWalletEngine__NotFromEntryPointOrOwner();
        }
        _;
    }

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert AbstraktWalletEngine__NotFromEntryPoint();
        }
        _;
    }

    modifier notFrozen() {
        if (s_frozenWallets[msg.sender]) {
            revert AbstraktWalletEngine__WalletFrozen();
        }
        _;
    }

    /*/////////////////////////////////////////////////////////////
                                FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with EntryPoint address
     * @param entryPoint The address of the ERC-4337 EntryPoint contract
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    /*/////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a transaction from the wallet
     * @dev Can only be called by EntryPoint or owner
     * @param dest Destination address
     * @param value ETH value to send
     * @param functionData Calldata for the transaction
     */
    function execute(address dest, uint256 value, bytes calldata functionData)
        external
        requireFromEntryPointOrOwner
        nonReentrant
        notFrozen
    {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert AbstraktWalletEngine__TransferFailed(result);
        }
    }

    /**
     * @notice Executes a batch of transactions
     * @dev Input arrays must be equal length
     * @param dests Array of destination addresses
     * @param values Array of ETH values to send
     * @param functionDatas Array of calldata for transactions
     */
    function executeBatch(address[] calldata dests, uint256[] calldata values, bytes[] calldata functionDatas)
        external
        requireFromEntryPointOrOwner
        nonReentrant
        notFrozen
    {
        if (dests.length != values.length || dests.length != functionDatas.length) {
            revert AbstraktWalletEngine__InvalidInputLengths();
        }

        for (uint256 i = 0; i < dests.length; i++) {
            (bool success, bytes memory result) = dests[i].call{value: values[i]}(functionDatas[i]);
            if (!success) {
                revert AbstraktWalletEngine__TransferFailed(result);
            }
        }
    }

    /**
     * @notice Validates user operation for ERC-4337 compliance
     * @dev Called by EntryPoint during operation processing
     * @param userOp The packed user operation data
     * @param userOpHash Hash of the user operation
     * @param missingAccountFunds Amount needing to be prepaid
     * @return validationData Signature validation result code
     */
    function validateUserOperation(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPreFund(missingAccountFunds);
    }

    /**
     * @notice Verifies user ownership via Google ID signature
     * @param googleId User's Google ID hash
     * @param signature ECDSA signature of (address, googleId) hash
     */
    function verifyUser(bytes32 googleId, bytes memory signature) external {
        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encodePacked(msg.sender, googleId)));

        address signer = ECDSA.recover(msgHash, signature);

        if (signer != owner()) {
            revert AbstraktWalletEngine__InvalidSignature();
        }

        s_googleIdToWallet[googleId] = msg.sender;

        emit UserVerified(msg.sender, googleId);
    }

    /**
     * @notice Registers WebAuthn public key hash for a wallet
     * @dev Restricted to EntryPoint or owner
     * @param pubKeyHash Hash of the WebAuthn public key
     */
    function registerWebAuthn(bytes32 pubKeyHash) external requireFromEntryPointOrOwner {
        s_webAuthnPubKeys[msg.sender] = pubKeyHash;
    }

    /**
     * @notice Validates WebAuthn challenge response
     * @param challenge Random challenge value
     * @return bool True if signed challenge matches stored public key
     */
    function validateWebAuthn(bytes32 challenge) external view returns (bool) {
        bytes32 signedHash = keccak256(abi.encodePacked(challenge, msg.sender));
        return s_webAuthnPubKeys[msg.sender] == signedHash;
    }

    /**
     * @notice Adds a guardian to the wallet
     * @dev Prevents duplicate guardians
     * @param guardian Address to add as guardian
     */
    function addGuardian(address guardian) external requireFromEntryPointOrOwner {
        address[] storage guardians = s_guardians[msg.sender];
        for (uint256 i = 0; i < guardians.length; i++) {
            if (guardians[i] == guardian) {
                revert AbstraktWalletEngine__GuardianAlreadyAdded();
            }
        }
        guardians.push(guardian);
        s_isGuardian[guardian] = true;
    }

    /**
     * @notice Approves recovery of a lost wallet
     * @dev Requires caller to be guardian of target wallet
     * @param lostUser Address of wallet needing recovery
     */
    function approveRecovery(address lostUser) external requireFromEntryPointOrOwner {
        if (!s_isGuardian[lostUser]) {
            revert AbstraktWalletEngine__NotGuardian();
        }

        s_guardianApprovals[lostUser]++;
        if (s_guardianApprovals[lostUser] >= GUARDIAN_THRESHOLD) {
            _transferOwnership(lostUser);
        }
    }

    /**
     * @notice Freezes a wallet preventing all operations
     * @dev Restricted to EntryPoint or owner
     * @param wallet Address to freeze
     */
    function freezeWallet(address wallet) external requireFromEntryPointOrOwner {
        s_frozenWallets[wallet] = true;
        emit WalletFrozen(wallet);
    }

    /**
     * @notice Unfreezes a previously frozen wallet
     * @dev Restricted to EntryPoint or owner
     * @param wallet Address to unfreeze
     */
    function unfreezeWallet(address wallet) external requireFromEntryPointOrOwner {
        s_frozenWallets[wallet] = false;
        emit WalletUnfrozen(wallet);
    }

    /*/////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates user operation signature
     * @param userOp The packed user operation
     * @param userOpHash Hash of the user operation
     * @return validationData Signature validation result code
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Processes prepayment for account abstraction operations
     * @param missingAccountFunds Amount needing to be prepaid
     */
    function _payPreFund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds}("");
            assert(success);
        }
    }

    /*/////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    /// @notice Returns the EntryPoint contract address
    function getEntryPoint() external view returns (IEntryPoint) {
        return i_entryPoint;
    }

    /// @notice Returns the guardian threshold required for recovery
    function getGuardianThreshold() external pure returns (uint8) {
        return GUARDIAN_THRESHOLD;
    }

    /// @notice Returns wallet address associated with a Google ID
    function getWalletFromGoogleId(bytes32 googleId) external view returns (address) {
        return s_googleIdToWallet[googleId];
    }

    /// @notice Returns list of guardians for a given address
    function getGuardians(address _address) external view returns (address[] memory) {
        return s_guardians[_address];
    }

    /// @notice Returns WebAuthn public key hash for a wallet
    function getWebAuthnPubKeys(address _address) external view returns (bytes32) {
        return s_webAuthnPubKeys[_address];
    }

    /// @notice Returns current guardian approvals count for recovery
    function getGuardianApprovals(address _address) external view returns (uint256) {
        return s_guardianApprovals[_address];
    }

    /// @notice Returns frozen status of a wallet
    function getFrozenWallets(address wallet) external view returns (bool) {
        return s_frozenWallets[wallet];
    }

    /// @notice Checks if an address is a guardian for any wallet
    function getGuardian(address _address) external view returns (bool) {
        return s_isGuardian[_address];
    }
}
