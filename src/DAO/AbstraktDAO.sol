// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeable} from "@openzeppelin-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from
    "@openzeppelin-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {GovernorSettingsUpgradeable} from
    "@openzeppelin-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorTimelockControlUpgradeable} from
    "@openzeppelin-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {GovernorVotesUpgradeable} from "@openzeppelin-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from
    "@openzeppelin-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockControllerUpgradeable} from "@openzeppelin-upgradeable/governance/TimelockControllerUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title AbstraktDAO
 * @author ArefXV https://github.com/arefxv
 * @dev Upgradeable DAO governance system with timelock-controlled proposals and quorum voting
 * @notice Combines OpenZeppelin Governor framework with UUPS upgradeability and security features
 * Features include:
 * - Proposal creation and voting with ERC20 token weights
 * - Timelock-controlled proposal execution
 * - Quorum requirements for proposal validity
 * - Upgradeable contract architecture with UUPS pattern
 * - Reentrancy protection for critical operations
 * - Owner-controlled upgrades and governance parameters
 */
contract AbstraktDAO is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*/////////////////////////////////////////////////////////////
                                    EVENTS
    /////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a proposal is queued in the timelock
    /// @param proposalId ID of the queued proposal
    /// @param descriptionHash Hash of the proposal description
    event OperationsQueued(uint256 proposalId, bytes32 descriptionHash);

    /// @notice Emitted when a proposal is executed from the timelock
    /// @param proposalId ID of the executed proposal
    /// @param descriptionHash Hash of the proposal description
    event OperationsExecuted(uint256 proposalId, bytes32 descriptionHash);

    /// @notice Emitted when a proposal is canceled
    /// @param proposalId ID of the canceled proposal
    /// @param descriptionHash Hash of the proposal description
    event Canceled(uint256 proposalId, bytes32 descriptionHash);

    /*/////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the DAO governance system
     * @dev Replaces constructor for upgradeable contracts
     * @param _token Governance token used for voting weights
     * @param _timelock Timelock controller for proposal execution
     * Initial configuration:
     * - Voting delay: 3 blocks
     * - Voting period: 50400 blocks (~1 week)
     * - Proposal threshold: 0 tokens
     * - Quorum: 4% of total token supply
     */
    function initialize(IVotes _token, TimelockControllerUpgradeable _timelock) public initializer {
        __Governor_init("AbstraktDAO");
        __GovernorSettings_init(3, 50400, 0);
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __GovernorTimelockControl_init(_timelock);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Returns the voting delay in blocks
     * @return uint256 Number of blocks before voting can begin
     */
    function votingDelay() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice Returns the voting period in blocks
     * @return uint256 Duration of voting period in blocks
     */
    function votingPeriod() public view override(GovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @notice Calculates required quorum for a given block
     * @param blockNumber Block number to calculate quorum for
     * @return uint256 Minimum number of votes required for proposal validity
     */
    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /**
     * @notice Returns current state of a proposal
     * @param proposalId ID of the proposal to check
     * @return ProposalState Current state of the proposal
     */
    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /**
     * @notice Checks if a proposal needs queuing in the timelock
     * @param proposalId ID of the proposal to check
     * @return bool True if proposal requires queuing
     */
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @notice Returns minimum token amount needed to create a proposal
     * @return uint256 Current proposal threshold
     */
    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /*/////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorizes contract upgrades (UUPS pattern)
     * @param newImplementation Address of the new implementation contract
     * @notice Restricted to contract owner only
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Queues proposal operations in the timelock
     * @param proposalId ID of the proposal to queue
     * @param targets Contract addresses to call
     * @param values ETH values for each call
     * @param calldatas Calldata for each call
     * @param descriptionHash Hash of the proposal description
     * @return uint48 Timestamp when operations become executable
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) nonReentrant returns (uint48) {
        emit OperationsQueued(proposalId, descriptionHash);
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Executes queued proposal operations
     * @param proposalId ID of the proposal to execute
     * @param targets Contract addresses to call
     * @param values ETH values for each call
     * @param calldatas Calldata for each call
     * @param descriptionHash Hash of the proposal description
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) nonReentrant {
        emit OperationsExecuted(proposalId, descriptionHash);
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Cancels a proposal before execution
     * @param targets Contract addresses in the proposal
     * @param values ETH values in the proposal
     * @param calldatas Calldata in the proposal
     * @param descriptionHash Hash of the proposal description
     * @return uint256 ID of the canceled proposal
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) nonReentrant returns (uint256) {
        uint256 proposalId = uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
        emit Canceled(proposalId, descriptionHash);
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Returns address of the timelock executor
     * @return address Timelock controller address
     */
    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    /*/////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function getVersion() external pure returns (uint8) {
        return 1;
    }
}
