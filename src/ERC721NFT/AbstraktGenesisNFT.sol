// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin-contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {console2} from "forge-std/console2.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

/**
 * @title AbstraktGenesisNFT
 * @author ArefXV https://github.com/arefxv
 * @dev ERC721 NFT contract with marketplace functionality and royalty system
 * @notice Features include:
 * - Fixed supply of 888 NFTs
 * - Minting with floor price enforcement
 * - Secondary market listing and trading
 * - 5% royalty fee on secondary sales
 * - Owner-controlled metadata URI
 * - User-specific token tracking
 * - Floor price protection for listings
 */
contract AbstraktGenesisNFT is ERC721, Ownable, CodeConstants {
    /*/////////////////////////////////////////////////////////////
                                    ERRORS
    /////////////////////////////////////////////////////////////*/
    /// @dev Thrown when setting duplicate base URI
    error AbstraktGenesisNFT__BaseTokenURIDuplicated(string, string);
    /// @dev Thrown when user attempts to mint more than once
    error AbstraktGenesisNFT__AlreadyMinted();
    /// @dev Thrown when max supply is reached
    error AbstraktGenesisNFT__MaxSupplyReached();
    /// @dev Thrown when invalid mint price is provided
    error AbstraktGenesisNFT__InvalidPrice(uint256);
    /// @dev Thrown when non-owner tries to list NFT
    error AbstraktGenesisNFT__NotNftOwner(address);
    /// @dev Thrown when listing below floor price
    error AbstraktGenesisNFT__CannotListNftLessThanFloorPrice(uint256);
    /// @dev Thrown when invalid input value is provided
    error AbstraktGenesisNFT__InvalidInputValue(uint256, uint256);
    /// @dev Thrown when buying unlisted NFT
    error AbstraktGenesisNFT__NotListedForSale();
    /// @dev Thrown when ETH transfer fails
    error AbstraktGenesisNFT__TransferFailed();
    /// @dev Thrown when querying unlisted token
    error AbstraktGenesisNFT__TokenHasNotListed(uint256);
    /// @dev Thrown when delisting with non-zero price
    error AbstraktGenesisNFT__PriceMustBeZeroForDelisting();

    /*/////////////////////////////////////////////////////////////
                                STATE VARIABLES
    /////////////////////////////////////////////////////////////*/
    /// @notice Maximum supply of NFTs
    uint256 private constant MAX_SUPPLY = 888;
    /// @notice Minimum price for minting and listing
    uint256 private constant FLOOR_PRICE = 1e17;
    /// @notice Precision for royalty calculations
    uint256 private constant PRECISION = 100;
    /// @notice Royalty fee percentage (5%)
    uint256 private constant ROYALTY_FEE_PERCENTAGE = 5;
    /// @notice Number of NFTs minted to owner on deployment
    uint256 private constant OWNER_MINT_AMOUNT = 19;
    /// @dev Counter for token IDs
    uint256 private s_tokenCounter;
    /// @dev Base URI for token metadata
    string private s_baseTokenURI;

    /// @dev Tracks mint status per address
    mapping(address => bool) private s_hasMinted;
    /// @dev Maps users to their owned token IDs
    mapping(address => uint256[]) private s_userToTokenIds;
    /// @dev Maps token IDs to their listing prices
    mapping(uint256 => uint256) private s_tokenIdPrice;
    /// @dev Tracks listing status per token ID
    mapping(uint256 => bool) private s_hasListed;

    /*/////////////////////////////////////////////////////////////
                                    EVENTS
    /////////////////////////////////////////////////////////////*/
    /// @notice Emitted when base URI is updated
    event NewBaseTokenURISet(string newTokenURI);
    /// @notice Emitted when new NFT is minted
    event NFTMinted(address indexed user, uint256 indexed tokenId);
    /// @notice Emitted when NFT is listed for sale
    event NFTListed(uint256 id, uint256 value);
    /// @notice Emitted when NFT is sold
    event NFTSold(address from, address to, uint256 id, uint256 value);
    /// @notice Emitted when NFT price is reset
    event NFTPriceReset(uint256 id);
    /// @notice Emitted when NFT is delisted
    event NFTDelisted(uint256 id);

    /*/////////////////////////////////////////////////////////////
                                    FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the NFT contract
     * @dev Mints initial batch to owner
     * @param baseURI Base URI for token metadata
     */
    constructor(string memory baseURI) ERC721("Abstrakt Genesis", "XV") Ownable(msg.sender) {
        s_tokenCounter = 0;
        s_baseTokenURI = baseURI;

        // Mint initial batch to owner
        for (uint256 i = 0; i < OWNER_MINT_AMOUNT; i++) {
            uint256 tokenId = s_tokenCounter;
            _safeMint(ACCOUNT, tokenId);
            s_userToTokenIds[owner()].push(tokenId);
            s_tokenCounter++;
        }
    }

    /*/////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    /**
     * @notice Updates base token URI
     * @dev Restricted to owner only
     * @param newBaseTokenURI New base URI for metadata
     */
    function setBaseTokenURI(string calldata newBaseTokenURI) external onlyOwner {
        if (keccak256(abi.encodePacked(s_baseTokenURI)) == keccak256(abi.encodePacked(newBaseTokenURI))) {
            revert AbstraktGenesisNFT__BaseTokenURIDuplicated(s_baseTokenURI, newBaseTokenURI);
        }
        s_baseTokenURI = newBaseTokenURI;

        emit NewBaseTokenURISet(newBaseTokenURI);
    }

    /**
     * @notice Mints a new NFT
     * @dev Requires exact floor price payment
     */
    function mintNFT() external payable {
        if (msg.value < FLOOR_PRICE) {
            revert AbstraktGenesisNFT__InvalidPrice(msg.value);
        }

        if (msg.value > FLOOR_PRICE) {
            (bool success,) = payable(msg.sender).call{value: msg.value - FLOOR_PRICE}("");
            if (!success) {
                revert AbstraktGenesisNFT__TransferFailed();
            }
        }

        if (s_tokenCounter >= MAX_SUPPLY) {
            revert AbstraktGenesisNFT__MaxSupplyReached();
        }

        uint256 tokenId = s_tokenCounter;

        if (s_hasMinted[msg.sender]) {
            revert AbstraktGenesisNFT__AlreadyMinted();
        }

        _safeMint(msg.sender, tokenId);
        console2.log("Your TokenID is", tokenId);
        s_hasMinted[msg.sender] = true;
        s_userToTokenIds[msg.sender].push(tokenId);

        emit NFTMinted(msg.sender, tokenId);

        ++s_tokenCounter;
    }

    /**
     * @notice Lists NFT for sale
     * @param tokenId ID of the NFT to list
     * @param price Listing price (must be >= floor price)
     */
    function listForSale(uint256 tokenId, uint256 price) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert AbstraktGenesisNFT__NotNftOwner(ownerOf(tokenId));
        }

        if (price < FLOOR_PRICE) {
            revert AbstraktGenesisNFT__CannotListNftLessThanFloorPrice(FLOOR_PRICE);
        }

        s_tokenIdPrice[tokenId] = price;
        s_hasListed[tokenId] = true;
        emit NFTListed(tokenId, price);
    }

    function listedNFTs(uint256 tokenId) external view {
        if (!s_hasListed[tokenId]) {
            revert AbstraktGenesisNFT__TokenHasNotListed(tokenId);
        }

        getListedTokens(tokenId);
        getTokenIdPrice(tokenId);
        console2.log("NFT Price :", getTokenIdPrice(tokenId));
    }

    /**
     * @notice Delists NFT from sale
     * @param tokenId ID of the NFT to delist
     * @param price Must be zero to confirm delisting
     */
    function delistNFT(uint256 tokenId, uint256 price) external {
        if (price == 0) {
            delete s_tokenIdPrice[tokenId];
            s_hasListed[tokenId] = false;
            emit NFTDelisted(tokenId);
        } else {
            revert AbstraktGenesisNFT__PriceMustBeZeroForDelisting();
        }
    }

    /**
     * @notice Buys listed NFT
     * @param tokenId ID of the NFT to purchase
     */
    function buyNFT(uint256 tokenId) external payable {
        uint256 tokenPrice = s_tokenIdPrice[tokenId];

        if (!s_hasListed[tokenId]) {
            revert AbstraktGenesisNFT__NotListedForSale();
        }

        if (msg.value != tokenPrice) {
            revert AbstraktGenesisNFT__InvalidInputValue(msg.value, tokenPrice);
        }

        address seller = ownerOf(tokenId);

        delete s_tokenIdPrice[tokenId];
        s_hasListed[tokenId] = false;
        _transfer(seller, msg.sender, tokenId);

        uint256 royaltyAmount = (tokenPrice * ROYALTY_FEE_PERCENTAGE) / PRECISION;
        uint256 sellerAmount = tokenPrice - royaltyAmount;

        (bool sellerSuccess,) = payable(seller).call{value: sellerAmount}("");
        assert(sellerSuccess);

        (bool ownerSuccess,) = payable(owner()).call{value: royaltyAmount}("");
        assert(ownerSuccess);

        emit NFTSold(seller, msg.sender, tokenId, tokenPrice);

        emit NFTPriceReset(tokenId);

        _removeTokenFromUser(seller, tokenId);

        s_userToTokenIds[msg.sender].push(tokenId);
    }

    /*/////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @dev Removes token from user's token list
     * @param user Address of the user
     * @param tokenId ID of the token to remove
     */
    function _removeTokenFromUser(address user, uint256 tokenId) internal {
        uint256[] storage userTokens = s_userToTokenIds[user];

        for (uint256 i = 0; i < userTokens.length; i++) {
            if (userTokens[i] == tokenId) {
                userTokens[i] = userTokens[userTokens.length - 1];
                userTokens.pop();
                break;
            }
        }
    }

    /*/////////////////////////////////////////////////////////////
                                PUBLIC FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns token URI for given token ID
     * @param tokenId ID of the token
     * @return string Token metadata URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(s_baseTokenURI, "/", Strings.toString(tokenId), ".json"));
    }

    /*/////////////////////////////////////////////////////////////
                                GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function getTotalMintedTokens() external view returns (uint256) {
        return s_tokenCounter;
    }

    function getBaseTokenURI() external view returns (string memory) {
        return s_baseTokenURI;
    }

    function getUserMintStatus(address user) external view returns (bool) {
        return s_hasMinted[user];
    }

    function getUserTokenIds(address user) external view returns (uint256[] memory) {
        return s_userToTokenIds[user];
    }

    function getFloorPrice() external pure returns (uint256) {
        return FLOOR_PRICE;
    }

    function getRoyaltyFeePercentage() external pure returns (uint256) {
        return ROYALTY_FEE_PERCENTAGE;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getTokenIdPrice(uint256 tokenId) public view returns (uint256) {
        return s_tokenIdPrice[tokenId];
    }

    function getListedTokens(uint256 tokenId) public view returns (bool) {
        return s_hasListed[tokenId];
    }
}
