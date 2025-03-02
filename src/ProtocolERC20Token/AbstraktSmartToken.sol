// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20Burnable, ERC20} from "@openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";
import {Checkers} from "../Helper/Checkers.sol";

/**
 * @title AbstraktSmartToken
 * @dev Basic ERC20 token with minting and burning capabilities.
 * @notice Features include:
 * - Owner-controlled minting
 * - Burnable tokens
 * - Access control for future extensions
 */
contract AbstraktSmartToken is ERC20, ERC20Burnable, Ownable, AccessControl, Checkers {
    error AbstraktSmartToken__AmountExceedsBalance();

    constructor() ERC20("Abstrakt Smart Token", "AST") Ownable(msg.sender) {}

    /**
     * @notice Mints new tokens
     * @param to Address to mint to
     * @param value Amount to mint
     * @return bool Success status
     */
    function mint(address to, uint256 value) external onlyOwner moreThanZero(value) nonAddressZero(to) returns (bool) {
        _mint(to, value);
        return true;
    }

    /**
     * @notice Burns tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) public override onlyOwner moreThanZero(amount) {
        uint256 balance = balanceOf(msg.sender);

        if (balance < amount) {
            revert AbstraktSmartToken__AmountExceedsBalance();
        }

        super.burn(amount);
    }
}
