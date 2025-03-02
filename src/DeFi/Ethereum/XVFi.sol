// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AbstraktGovernToken} from "../../GovernERC20Token/AbstraktGovernToken.sol";
import {AbstraktSmartToken, Checkers} from "../../ProtocolERC20Token/AbstraktSmartToken.sol";
import {IAbstraktSmartToken, IAbstraktGovernToken} from "../../Interface/IAbstraktSmartToken.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AbstraktGenesisNFT, ERC721} from "../../ERC721NFT/AbstraktGenesisNFT.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {OracleLib, AggregatorV3Interface} from "./../libraries/OracleLib.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title XVFi
 * @author ArefXV https://github.com/arefxv
 * @dev The XVFi smart contract is a decentralized finance (DeFi) protocol built on the ERC-20 and ERC-721 standards
 * This contract enables users to stake tokens, lend, and use collateralized assets
 * Key Features:
 * Staking & Rewards: Users can stake their tokens and receive rewards
 * Lending & Collateralization System: Users can mint new tokens or receive loans by collateralizing their tokens
 * Liquidation Mechanism: If a user's health factor falls below a specified threshold, their collateral will be liquidated
 * Role & Permission Management: The contract utilizes {AccessControlUpgradeable} for role-based access control
 * Oracle Integration: The contract uses the OracleLib library to fetch asset prices from external sources
 * @notice This smart contract is upgradeable and has been developed exclusively for testing purposes. It is not intended for production use in its current state
 * @notice During testing, the collateral asset considered was ETH,
 * -meaning that all operations related to collateral were carried out using Ethereum
 * @notice The AST token used within this protocol follows the ERC20 standard. You can view
 * -its contract implementation at {AbstraktSmartToken.sol}
 * @notice  AGT is the governance token of this protocol, allowing holders to participate in decision-making processes
 * -The contract can be found at {AbstraktGovernToken}
 * @notice The NFT utilized in this protocol adheres to the ERC721 standard. Its contract implementation
 * -is available at {AbstraktGenesisNFT}
 * IMPORTANT @notice Although this contract has undergone initial testing by the developer, it has not been audited yet
 * -Before any real world deployment or financial interactions, it is strongly recommended that
 * -A professional security audit is conducted to identify potential vulnerabilities
 * -Any individual or entity intending to use the contract performs thorough independent testing to ensure its reliability and security
 * -Failure to properly audit and test the contract may result in unexpected risks, security breaches, or financial losses
 */
contract XVFi is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    Checkers,
    AccessControlUpgradeable
{
    using SafeERC20 for IAbstraktSmartToken;
    using SafeERC20 for IAbstraktGovernToken;
    using OracleLib for AggregatorV3Interface;

    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/
    error XVFi__InsufficientAmountToRedeem(uint256, uint256);
    error XVFi__TransferFailed();
    error XVFi__BreaksHealthFactor(uint256);
    error XVFi__MintFailed();
    error XVFi__HealthFactorIsOk(uint256);
    error XVFi__OnlyNftHoldersCanEnter();
    error XVFi__InvalidTokenAddress(address, address);
    error XVFi__NotOwnerOfThisToken(uint256);
    error XVFi__InsufficientStakedAmount(uint256, uint256);
    error XVFi__NoRewardToClaim();
    error XVFi__TokenNotStaked(uint256);
    error XVFi__LockUpEndTimeNotPassed(uint256, uint256);
    error XVFi__WrongNftOwner();
    error XVFi__NftNotLocked();

    /*/////////////////////////////////////////////////////////////
                                TYPES
    /////////////////////////////////////////////////////////////*/

    struct StakeInfo {
        address account;
        address ownTokenId;
        uint256 timestamp;
        uint256 stakeAmount;
        uint256 tokenId;
        uint256 interestRate;
        uint256 lockUpEndTimestamp;
    }

    /*/////////////////////////////////////////////////////////////
                            STATE VARIABLES
    /////////////////////////////////////////////////////////////*/

    uint8 private constant LIQUIDATION_THRESHOLD = 50;
    uint8 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint8 private constant LIQUIDATION_BONUS = 10;

    bytes32 private constant SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE = keccak256("SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE");
    bytes32 private constant SET_NEW_LOCKUP_END_TIME = keccak256("SET_NEW_LOCKUP_END_TIME");

    uint256 private s_minAmount;
    uint256 private s_interestRate = 7e16;
    uint256 private s_lockUpEndTimestamp = 30 days;
    address private s_collateralToken;
    AggregatorV3Interface private s_priceFeed;

    mapping(address => uint256) private s_userDepositedCollateral;
    mapping(address => uint256) private s_userAstMinted;
    mapping(address => StakeInfo[]) private s_userAgtStaked;
    mapping(uint256 => address) private s_lockedTokenIdToAddress;

    IAbstraktSmartToken private ast;
    IAbstraktGovernToken private agt;
    AbstraktGenesisNFT private nft;

    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/

    event NewMinCollateralAmountSet(uint256 newAmount);
    event CollateralDeposited(address user, uint256 amount);
    event CollateralRedeemed(address from, address to, uint256 amount);
    event AstMinted(address indexed user, uint256 indexed amount);
    event AstBurned(address indexed user, uint256 indexed amount);
    event AgtStaked(address indexed user, uint256 indexed amount);
    event InterestRateSet(uint256 newInterestRate);
    event RewardClaimed(address user, uint256 amount);
    event AgtUnstaked(address user, uint256 amount, uint256 tokenId);
    event NewLockUpTimestampSet(uint256 newTime);

    /*/////////////////////////////////////////////////////////////
                                MODIFIERS
    /////////////////////////////////////////////////////////////*/

    modifier onlyNftHolders(uint256 tokenId) {
        if (nft.ownerOf(tokenId) != msg.sender) {
            revert XVFi__OnlyNftHoldersCanEnter();
        }
        _;
    }

    /*/////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the smart contract with required external contract addresses and sets up roles
     * @dev This function can only be called once due to the `initializer` modifier
     * @param tokenAddress The address of the collateral token used in the protocol
     * @param priceFeedAddress The address of the Chainlink price feed contract
     * @param astAddress The address of the AST (Abstrakt Smart Token) contract
     * @param agtAddress The address of the AGT (Abstrakt Governance Token) contract
     * @param nftAddress The address of the NFT (Abstrakt Genesis NFT) contract used in the protocol
     */
    function initialize(
        address tokenAddress,
        address priceFeedAddress,
        address astAddress,
        address agtAddress,
        address nftAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __AccessControl_init();

        ast = IAbstraktSmartToken(astAddress);
        agt = IAbstraktGovernToken(agtAddress);
        nft = AbstraktGenesisNFT(nftAddress);
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
        s_collateralToken = tokenAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE, owner());
        _grantRole(SET_NEW_LOCKUP_END_TIME, owner());
    }

    /**
     * @notice Grants the role to set a new minimum collateral amount
     * @dev Only the contract owner can call this function
     * @param to The address that will receive the `SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE` role
     */
    function grantSetNewMinCollateralAmountRole(address to) external onlyOwner nonAddressZero(to) {
        grantRole(SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE, to);
    }

    /**
     * @notice Grants the role to set a new lock-up end timestamp.
     * @dev Only the contract owner can call this function.
     * @param to The address that will receive the `SET_NEW_LOCKUP_END_TIME` role.
     */
    function grantSetNewLockUpTimeRole(address to) external onlyOwner nonAddressZero(to) {
        grantRole(SET_NEW_LOCKUP_END_TIME, to);
    }

    /**
     * @notice Updates the minimum required collateral amount
     * @dev Only addresses with the `SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE` role can call this function
     * @param newMinAmount The new minimum collateral amount
     */
    function setNewMinAmount(uint256 newMinAmount) external onlyRole(SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE) {
        s_minAmount = newMinAmount;
        emit NewMinCollateralAmountSet(newMinAmount);
    }

    /**
     * @notice Updates the lock-up end timestamp for staked assets
     * @dev Only addresses with the `SET_NEW_LOCKUP_END_TIME` role can call this function
     * @param newTime The new lock-up end timestamp
     */
    function setNewLockUpEndTimestamp(uint256 newTime) external onlyRole(SET_NEW_LOCKUP_END_TIME) {
        s_lockUpEndTimestamp = newTime;
        emit NewLockUpTimestampSet(newTime);
    }

    /**
     * @notice Updates the interest rate for governance token staking rewards
     * @dev Only the contract owner can call this function. It interacts with the AGT contract to set the new rate
     * @param _newInterestRate The new interest rate to be set
     */
    function setNewInterestRate(uint256 _newInterestRate)
        external
        onlyOwner
        newInterestRate(s_interestRate, _newInterestRate)
    {
        IAbstraktGovernToken(agt).setInterestRate(_newInterestRate);

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Deposits collateral and mints an equivalent amount of AST tokens
     * @dev Ensures the amount to mint is greater than zero and prevents reentrancy attacks
     * @param amountAstToMint The amount of AST tokens to mint
     */
    function depositCollateralAndMintAst(uint256 amountAstToMint) external nonReentrant moreThanZero(amountAstToMint) {
        depositCollateral();
        mintAst(amountAstToMint);
    }

    /**
     * @notice Redeems collateral by burning AST tokens
     * @dev Ensures the amount is greater than zero, burns AST tokens, and checks the health factor
     * @param amountCollateral The amount of collateral to redeem
     * @param amountToBurn The amount of AST tokens to burn
     */
    function redeemCollateralForAst(uint256 amountCollateral, uint256 amountToBurn)
        external
        moreThanZero(amountCollateral)
    {
        _burnAst(amountToBurn, msg.sender, msg.sender);
        _redeemCollateral(amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Redeems a specified amount of collateral
     * @dev Ensures the amount is greater than zero and verifies the health factor after redemption
     * @param amountCollateral The amount of collateral to redeem
     */
    function redeemCollateral(uint256 amountCollateral) external nonReentrant moreThanZero(amountCollateral) {
        _redeemCollateral(amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates a user whose health factor is below the minimum threshold
     * @dev Converts the user's debt into collateral, applies a liquidation bonus, and burns AST tokens
     * @param user The address of the user to be liquidated
     * @param debtToCover The amount of debt to be covered during liquidation
     */
    function liquidate(address user, uint256 debtToCover)
        external
        nonReentrant
        nonAddressZero(user)
        moreThanZero(debtToCover)
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert XVFi__HealthFactorIsOk(startingUserHealthFactor);
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(debtToCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        _redeemCollateral(tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnAst(debtToCover, user, msg.sender);
    }

    /**
     * @notice Burns a specified amount of AST tokens
     * @dev Ensures the amount is greater than zero and verifies the health factor after burning
     * @param amountToBurn The amount of AST tokens to burn
     */
    function burnAst(uint256 amountToBurn) external moreThanZero(amountToBurn) {
        _burnAst(amountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Stakes AGT tokens along with an NFT
     * @dev Only NFT holders can stake AGT tokens. The function locks the NFT and AGT tokens in the contract
     * @param tokenId The ID of the NFT used for staking
     * @param amountAgtToStake The amount of AGT tokens to stake
     */
    function stakeAgt(uint256 tokenId, uint256 amountAgtToStake)
        external
        nonReentrant
        onlyNftHolders(tokenId)
        moreThanZero(amountAgtToStake)
    {
        s_userAgtStaked[msg.sender].push(
            StakeInfo({
                account: msg.sender,
                ownTokenId: nft.ownerOf(tokenId),
                timestamp: block.timestamp,
                stakeAmount: amountAgtToStake,
                tokenId: tokenId,
                interestRate: s_interestRate,
                lockUpEndTimestamp: s_lockUpEndTimestamp
            })
        );

        s_lockedTokenIdToAddress[tokenId] = msg.sender;

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        agt.safeTransferFrom(msg.sender, address(this), amountAgtToStake);

        emit AgtStaked(msg.sender, amountAgtToStake);
    }

    /**
     * @notice Unstakes AGT tokens and claims the staking rewards
     * @dev Ensures the staker owns the NFT and has sufficient staked AGT tokens. The NFT is returned if fully unstaked
     * @param tokenId The ID of the NFT used for staking
     * @param amountAgtToUnstake The amount of AGT tokens to unstake
     */
    function unstakeAgtAndClaimReward(uint256 tokenId, uint256 amountAgtToUnstake)
        external
        nonReentrant
        moreThanZero(amountAgtToUnstake)
    {
        StakeInfo[] storage stakes = s_userAgtStaked[msg.sender];

        uint256 remainingStake = 0;
        bool tokenIdFound = false;

        for (uint256 i = 0; i < stakes.length; i++) {
            if (stakes[i].tokenId == tokenId) {
                tokenIdFound = true;
                if (stakes[i].ownTokenId != msg.sender) {
                    revert XVFi__NotOwnerOfThisToken(tokenId);
                }
                if (stakes[i].stakeAmount < amountAgtToUnstake) {
                    revert XVFi__InsufficientStakedAmount(stakes[i].stakeAmount, amountAgtToUnstake);
                }
                if (block.timestamp < stakes[i].lockUpEndTimestamp) {
                    revert XVFi__LockUpEndTimeNotPassed(stakes[i].lockUpEndTimestamp, s_lockUpEndTimestamp);
                }

                stakes[i].stakeAmount -= amountAgtToUnstake;
                remainingStake += stakes[i].stakeAmount;

                if (remainingStake > 0) {
                    stakes[i].lockUpEndTimestamp = block.timestamp + s_lockUpEndTimestamp;
                } else {
                    delete s_lockedTokenIdToAddress[tokenId];
                    nft.safeTransferFrom(address(this), msg.sender, tokenId);
                }
                break;
            }
        }

        if (!tokenIdFound) {
            revert XVFi__TokenNotStaked(tokenId);
        }

        uint256 reward = _claimReward(msg.sender);

        if (reward > 0) {
            agt.safeTransfer(msg.sender, amountAgtToUnstake + reward);
        } else {
            agt.safeTransfer(msg.sender, amountAgtToUnstake);
        }

        emit AgtUnstaked(msg.sender, amountAgtToUnstake, tokenId);
    }

    /**
     * @notice Reclaim a locked NFT and transfer it to the specified address
     * @dev This function allows the owner to reclaim a previously locked NFT and send it to a specified address
     * @param tokenId The ID of the NFT to reclaim
     * @param to The address to which the NFT will be transferred
     */
    function reclaimNft(uint256 tokenId, address to) external onlyOwner {
        if (s_lockedTokenIdToAddress[tokenId] != to) {
            revert XVFi__WrongNftOwner();
        }

        if (nft.ownerOf(tokenId) != address(this)) {
            revert XVFi__NftNotLocked();
        }

        delete s_lockedTokenIdToAddress[tokenId];
        nft.safeTransferFrom(address(this), to, tokenId);
    }

    /**
     * @notice Claim available rewards for the caller.
     * @dev This function allows users to claim their rewards in AGT tokens. The reward amount is calculated based on the user's activity or stake.
     */
    function claimReward() external nonReentrant {
        uint256 reward = _claimReward(msg.sender);
        if (reward > 0) {
            agt.safeTransfer(msg.sender, reward);
        } else {
            revert XVFi__NoRewardToClaim();
        }
    }

    /*/////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit collateral to the contract
     * @dev The deposited amount is recorded and emitted as an event
     */
    function depositCollateral()
        public
        payable
        nonReentrant
        moreThanZero(msg.value)
        minAmount(msg.value, s_minAmount)
    {
        s_userDepositedCollateral[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Mint AST tokens.
     * @dev This function allows users to mint AST tokens based on a specified amount.
     * @param amountAstToMint The amount of AST tokens to mint.
     */
    function mintAst(uint256 amountAstToMint) public nonReentrant moreThanZero(amountAstToMint) {
        s_userAstMinted[msg.sender] += amountAstToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = ast.mint(msg.sender, amountAstToMint);

        emit AstMinted(msg.sender, amountAstToMint);

        if (!minted) {
            revert XVFi__MintFailed();
        }
    }

    /*/////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function _calculateHealthFactor(uint256 totalAstMinted, uint256 collateralValueInUsd)
        internal
        pure
        returns (uint256)
    {
        if (totalAstMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalAstMinted;
    }

    /// @notice Revert if the user's health factor is below the required threshold
    /// @dev The health factor should not drop below `MIN_HEALTH_FACTOR`. If it does, the function reverts
    /// @param user The user's address
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert XVFi__BreaksHealthFactor(userHealthFactor);
        }
    }

    /**
     * @notice Claim rewards based on the amount of AGT tokens staked.
     * @dev This function calculates and transfers the rewards to the user.
     * @param user The address of the user claiming the reward.
     */
    function _claimReward(address user) internal returns (uint256) {
        StakeInfo[] storage stakes = s_userAgtStaked[user];
        uint256 totalInterest = 0;

        for (uint256 i; i < stakes.length; i++) {
            uint256 timeDifference = block.timestamp - stakes[i].timestamp;
            uint256 reward = (stakes[i].stakeAmount * stakes[i].interestRate * timeDifference) / PRECISION;
            stakes[i].timestamp = block.timestamp;
            totalInterest += reward;
        }

        if (totalInterest > 0) {
            agt.transfer(user, totalInterest);
            emit RewardClaimed(user, totalInterest);
        }

        return totalInterest;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*/////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeem a specified amount of collateral from the contract
     * @dev This function allows users to redeem collateral. The contract checks if the user has enough collateral to redeem
     * @param amountToRedeem The amount of collateral to redeem
     * @param from The address of the user redeeming collateral
     * @param to The address receiving the collateral
     */
    function _redeemCollateral(uint256 amountToRedeem, address from, address to) private {
        uint256 userDepositedCollateralAmount = s_userDepositedCollateral[from];

        if (userDepositedCollateralAmount < amountToRedeem) {
            revert XVFi__InsufficientAmountToRedeem(userDepositedCollateralAmount, amountToRedeem);
        }

        s_userDepositedCollateral[from] -= amountToRedeem;

        emit CollateralRedeemed(from, to, amountToRedeem);

        (bool success,) = payable(to).call{value: amountToRedeem}("");
        if (!success) {
            revert XVFi__TransferFailed();
        }
    }

    /**
     * @notice Burn a specified amount of AST tokens from a user.
     * @dev This function burns AST tokens, reducing the user's minted balance. The tokens are transferred from the user to the contract before burning.
     * @param amountToBurn The amount of AST tokens to burn.
     * @param onBehalfOf The address for which the tokens are being burned.
     * @param astFrom The address from which the tokens are transferred before burning.
     */
    function _burnAst(uint256 amountToBurn, address onBehalfOf, address astFrom) private {
        s_userAstMinted[onBehalfOf] -= amountToBurn;

        ast.safeTransferFrom(astFrom, address(this), amountToBurn);

        emit AstBurned(onBehalfOf, amountToBurn);
        ast.burn(amountToBurn);
    }

    /**
     * @notice Get the USD value of a specified amount of tokens
     * @dev This function uses a price feed to calculate the USD value of a given amount of tokens
     * @param amount The amount of tokens to convert to USD
     * @return The USD value of the specified amount of tokens
     */
    function _getUsdValue(uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = s_priceFeed;
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /**
     * @notice Retrieve account information for a user, including total AST minted and collateral value in USD
     * @dev This function fetches the necessary account information to calculate the health factor
     * @param user The address of the user
     * @return totalAstMinted The total amount of AST tokens minted by the user
     * @return collateralValueInUsd The value of the user's collateral in USD
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalAstMinted, uint256 collateralValueInUsd)
    {
        totalAstMinted = s_userAstMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Calculate the health factor of a user based on their collateral and minted AST tokens
     * @dev The health factor is used to determine the user's solvency. If it falls below a threshold, certain actions may be prevented
     * @param user The address of the user
     * @return The calculated health factor
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalAstMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalAstMinted, collateralValueInUsd);
    }

    /*/////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 amount = s_userDepositedCollateral[user];

        uint256 totalCollateralValueInUsd = _getUsdValue(amount);

        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = s_priceFeed;
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getMinimumCollateralAmount() external view returns (uint256) {
        return s_minAmount;
    }

    function getCollateralTokenAddress() external view returns (address) {
        return s_collateralToken;
    }

    function getTokenPriceFeedAddress() external view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    function getUserDepositedCollateralAmount(address user) external view returns (uint256) {
        return s_userDepositedCollateral[user];
    }

    function getUserTotalAstMintedAmount(address user) external view returns (uint256) {
        return s_userAstMinted[user];
    }

    function getAstTokenAddress() external view returns (IAbstraktSmartToken) {
        return IAbstraktSmartToken(address(ast));
    }

    function getNftAddress() external view returns (AbstraktGenesisNFT) {
        return AbstraktGenesisNFT(nft);
    }

    function getSetNewMinAmountRole() external pure returns (bytes32) {
        return SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getMinimumHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getUserStakeInfo(address user) external view returns (StakeInfo[] memory) {
        return s_userAgtStaked[user];
    }

    function getUserPendingReward(address user) external view returns (uint256) {
        StakeInfo[] storage stakes = s_userAgtStaked[user];
        uint256 totalInterest = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            uint256 timeDifference = block.timestamp - stakes[i].timestamp;
            uint256 reward = (stakes[i].stakeAmount * stakes[i].interestRate * timeDifference) / PRECISION;
            totalInterest += reward;
        }

        return totalInterest;
    }

    function getVersion() external pure returns (uint256) {
        return 1;
    }

    function getSetNewMinCollateralAmountRole() external pure returns (bytes32) {
        return SET_NEW_MIN_COLLATERAL_AMOUNT_ROLE;
    }

    function getSetNewLockUpTimeRole() external pure returns (bytes32) {
        return SET_NEW_LOCKUP_END_TIME;
    }
}
