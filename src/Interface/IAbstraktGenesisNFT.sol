// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {IERC721} from "@openzeppelin-contracts/token/ERC721/IERC721.sol";

interface IAbstraktGenesisNFT is IERC721 {
    function mintNFT() external payable;

    function listForSale(uint256 tokenId, uint256 price) external;

    function listedNFTs(uint256 tokenId) external view;

    function delistNFT(uint256 tokenId, uint256 price) external;

    function buyNFT(uint256 tokenId) external payable;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function getTotalMintedTokens() external view returns (uint256);

    function getListedTokens(uint256 tokenId) external view returns (bool);

    function getTokenIdPrice(uint256 tokenId) external view returns (uint256);

    function getPrecision() external pure returns (uint256);

    function getRoyaltyFeePercentage() external pure returns (uint256);

    function getFloorPrice() external pure returns (uint256);

    function getUserTokenIds(address user) external view returns (uint256[] memory);

    function getUserMintStatus(address user) external view returns (bool);

    function getBaseTokenURI() external view returns (string memory);
}
