// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink-brownie/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink-brownie/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from
    "@chainlink-brownie/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {Checkers} from "../Helper/Checkers.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IAbstraktGenesisNFT} from "../Interface/IAbstraktGenesisNFT.sol";

/**
 * @title LuckyStrakt
 * @author ArefXV https://github.com/arefxv
 * @dev A decentralized lottery system with Chainlink VRF for randomness and Automation for periodic draws.
 * @notice Features include:
 * - Two-tier lottery system: Paid entries and NFT-based VIP entries
 * - Chainlink VRF for provably fair winner selection
 * - Chainlink Automation for periodic draws
 * - Non-reentrant and secure fund distribution
 * - NFT-based VIP participation
 */
contract LuckyStrakt is VRFConsumerBaseV2Plus, AutomationCompatibleInterface, Checkers, ReentrancyGuard {
    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/
    error LuckyStrakt__SendMoreAmountToEnter(uint256);
    error LuckyStrakt__LotteryIsClosed();
    error LuckyStrakt__InvalidTokenId(uint256);
    error LuckyStrakt__UpkeepNotNeeded(uint256, uint256, uint256, uint256);
    error LuckyStrakt__TransferFailed();
    error LuckyStrakt__TokenAlreadyUsed(uint256);
    error LuckyStrakt__NoParticipants();

    /*/////////////////////////////////////////////////////////////
                                    TYPES
    /////////////////////////////////////////////////////////////*/
    enum LotteryState {
        OPEN,
        CALCULATING
    }

    /*/////////////////////////////////////////////////////////////
                            STATE VARIABLES
    /////////////////////////////////////////////////////////////*/

    /// @notice Chainlink VRF gas lane key hash
    bytes32 private immutable i_gasLane;
    /// @notice Chainlink VRF subscription ID
    uint256 private immutable i_subId;
    /// @notice Chainlink VRF callback gas limit
    uint32 private immutable i_callbackGasLimit;
    /// @notice Chainlink VRF request confirmations
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    /// @notice Number of random words to request
    uint32 private constant NUM_WORDS = 1;

    /// @notice Current entrance fee for paid entries
    uint256 private s_entranceFee;
    /// @notice Interval between lottery draws
    uint256 private immutable i_interval;
    /// @notice Timestamp of last draw
    uint256 private s_lastTimestamp;

    /// @notice List of paid participants
    address payable[] private s_players;
    /// @notice List of VIP participants (NFT holders)
    address payable[] private s_vipPlayers;

    /// @notice Recent paid winner address
    address private s_recentPaidWinner;
    /// @notice Recent VIP winner address
    address private s_recentVipWinner;

    /// @notice Tracks used NFT tokens
    mapping(uint256 => bool) private s_nftUsed;

    /// @notice AbstraktGenesisNFT contract address
    IAbstraktGenesisNFT private immutable i_abstraktGenesisNftAddress;
    /// @notice Current lottery state
    LotteryState private s_lotteryState;

    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/

    event NewEntranceFeeSet(uint256 value);
    event PaidLotteryEnter(address user);
    event NftLotteryEnter(address user);
    event PaidWinnerPicked(address recentPaidWinner);
    event VipWinnerPicked(address recentVipWinner);
    event RequestedLotteryWinner(uint256 requestId);

    /*/////////////////////////////////////////////////////////////
                            FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the lottery contract
     * @param entranceFee Initial entrance fee for paid entries
     * @param interval Time between lottery draws
     * @param gasLane Chainlink VRF gas lane key hash
     * @param subId Chainlink VRF subscription ID
     * @param callbackGasLimit Chainlink VRF callback gas limit
     * @param vrfCoordinatorV2 Chainlink VRF coordinator address
     * @param abstraktGenesisNftAddress AbstraktGenesisNFT contract address
     */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint256 subId,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        IAbstraktGenesisNFT abstraktGenesisNftAddress
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        s_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_gasLane = gasLane;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;
        i_abstraktGenesisNftAddress = abstraktGenesisNftAddress;
        s_lotteryState = LotteryState.OPEN;
    }

    /*/////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets new entrance fee for paid entries
     * @param newEntranceFee New entrance fee amount
     */
    function setNewEntranceFee(uint256 newEntranceFee) external onlyOwner moreThanZero(newEntranceFee) {
        s_entranceFee = newEntranceFee;
        emit NewEntranceFeeSet(newEntranceFee);
    }

    /**
     * @notice Enters lottery with ETH payment
     * @dev Requires exact entrance fee amount
     */
    function enterLotteryWithEntranceFee() external payable {
        if (msg.value < s_entranceFee) {
            revert LuckyStrakt__SendMoreAmountToEnter(s_entranceFee);
        }

        if (s_lotteryState != LotteryState.OPEN) {
            revert LuckyStrakt__LotteryIsClosed();
        }

        s_players.push(payable(msg.sender));

        emit PaidLotteryEnter(msg.sender);
    }

    /**
     * @notice Enters lottery with NFT
     * @param tokenId NFT token ID for VIP entry
     */
    function enterLotteryWithNFT(uint256 tokenId) external {
        if (i_abstraktGenesisNftAddress.ownerOf(tokenId) != msg.sender) {
            revert LuckyStrakt__InvalidTokenId(tokenId);
        }

        if (s_nftUsed[tokenId]) {
            revert LuckyStrakt__TokenAlreadyUsed(tokenId);
        }

        if (s_lotteryState != LotteryState.OPEN) {
            revert LuckyStrakt__LotteryIsClosed();
        }

        s_nftUsed[tokenId] = true;
        s_vipPlayers.push(payable(msg.sender));

        emit NftLotteryEnter(msg.sender);
    }

    /*/////////////////////////////////////////////////////////////
                        CHAINLINK FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if upkeep is needed
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     */
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool isOpen = LotteryState.OPEN == s_lotteryState;
        bool timePassed = ((block.timestamp - s_lastTimestamp) > i_interval);
        bool hasPaidPlayers = s_players.length > 0;
        bool hasVipPlayers = s_vipPlayers.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPaidPlayers && hasVipPlayers && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @notice Performs upkeep and requests random winner
     */
    function performUpkeep(bytes memory /*performData*/ ) external override {
        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert LuckyStrakt__UpkeepNotNeeded(
                s_players.length, s_vipPlayers.length, address(this).balance, uint256(s_lotteryState)
            );
        }

        s_lotteryState = LotteryState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) // set false to pay for VRF requests with LINK (true with sepolia ETH)
            })
        );
        emit RequestedLotteryWinner(requestId);
    }

    /**
     * @notice Callback function for Chainlink VRF
     * @param randomWords Array of random numbers from VRF
     */
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override nonReentrant {
        if (s_players.length == 0 || s_vipPlayers.length == 0) {
            revert LuckyStrakt__NoParticipants();
        }

        uint256 indexOfPaidWinner = randomWords[0] % s_players.length;
        uint256 indexOfVipWinner = randomWords[0] % s_vipPlayers.length;

        address payable recentPaidWinner = s_players[indexOfPaidWinner];
        address payable recentVipWinner = s_vipPlayers[indexOfVipWinner];

        s_recentPaidWinner = recentPaidWinner;
        s_recentVipWinner = recentVipWinner;

        delete s_players;
        delete s_vipPlayers;

        s_lotteryState = LotteryState.OPEN;

        s_lastTimestamp = block.timestamp;

        emit PaidWinnerPicked(recentPaidWinner);
        emit VipWinnerPicked(recentVipWinner);

        uint256 totalBalance = address(this).balance;
        uint256 paidAmount = totalBalance / 3;
        uint256 vipAmount = totalBalance - paidAmount;

        (bool successPaid,) = recentPaidWinner.call{value: paidAmount}("");
        if (!successPaid) {
            revert LuckyStrakt__TransferFailed();
        }

        (bool successVip,) = recentVipWinner.call{value: vipAmount}("");
        if (!successVip) {
            revert LuckyStrakt__TransferFailed();
        }
    }

    /*/////////////////////////////////////////////////////////////
                        GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /// @notice Returns current entrance fee
    function getEntranceFee() external view returns (uint256) {
        return s_entranceFee;
    }

    /// @notice Returns current lottery state
    function getLotteryState() external view returns (LotteryState) {
        return s_lotteryState;
    }

    /// @notice Returns draw interval
    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    /// @notice Returns NFT contract address
    function getNftContractAddress() external view returns (IAbstraktGenesisNFT) {
        return i_abstraktGenesisNftAddress;
    }

    /// @notice Returns number of paid participants
    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    /// @notice Returns number of VIP participants
    function getVipPlayersCount() external view returns (uint256) {
        return s_vipPlayers.length;
    }

    /// @notice Checks if NFT token is used
    function getUsedNft(uint256 tokenId) external view returns (bool) {
        return s_nftUsed[tokenId];
    }
}
