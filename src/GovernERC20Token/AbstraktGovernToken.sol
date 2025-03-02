// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Checkers} from "../Helper/Checkers.sol";
import {AccessControl} from "@openzeppelin-contracts/access/AccessControl.sol";

/**
 * @title AbstraktGovernToken
 * @author ArefXV https://github.com/arefxv
 * @dev Governance token with voting power, permit functionality, and interest rate mechanism.
 * @notice Features include:
 * - ERC20Votes for governance voting
 * - ERC20Permit for gasless approvals
 * - Interest rate system for token holders
 * - Role-based minting and burning
 */
contract AbstraktGovernToken is ERC20, ERC20Permit, ERC20Votes, ERC20Burnable, Ownable, Checkers, AccessControl {
    /*/////////////////////////////////////////////////////////////
                                ERRORS
    /////////////////////////////////////////////////////////////*/

    error AbstraktGovernToken__BurnAmountExceedsBalance();
    error AbstraktSmartToken__InterestRateCanOnlyDecrease();

    /*/////////////////////////////////////////////////////////////
                            STATE VARIABLES
    /////////////////////////////////////////////////////////////*/
    uint256 private s_interestRate = 7e16;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    mapping(address => uint256) private s_accountInterestRate;

    /*/////////////////////////////////////////////////////////////
                                EVENTS
    /////////////////////////////////////////////////////////////*/
    event RoleGranted(address _address);

    /*/////////////////////////////////////////////////////////////
                            FUNCTIONS
    /////////////////////////////////////////////////////////////*/
    constructor() ERC20("AbstraktGovernToken", "MTK") ERC20Permit("AbstraktGovernToken") Ownable(msg.sender) {}

    /*/////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets new interest rate
     * @param newInterestRate New interest rate value
     */
    function setInterestRate(uint256 newInterestRate) external onlyOwner {
        if (newInterestRate >= s_interestRate) {
            revert AbstraktSmartToken__InterestRateCanOnlyDecrease();
        }

        s_interestRate = newInterestRate;
    }

    /**
     * @notice Grants mint/burn role to address
     * @param to Address to grant role
     */
    function grantMintAndBurnRole(address to) external onlyOwner nonAddressZero(to) {
        _grantRole(MINT_AND_BURN_ROLE, to);

        emit RoleGranted(to);
    }

    /**
     * @notice Mints tokens with interest rate
     * @param to Address to mint to
     * @param value Amount to mint
     * @param accountInterestRate Interest rate for account
     */
    function mint(address to, uint256 value, uint256 accountInterestRate)
        external
        onlyRole(MINT_AND_BURN_ROLE)
        nonAddressZero(to)
        moreThanZero(value)
    {
        s_accountInterestRate[to] = accountInterestRate;

        _mint(to, value);
    }

    function mint(address to, uint256 value) public onlyOwner nonAddressZero(to) moreThanZero(value) {
        _mint(to, value);
    }

    /**
     * @notice Burns tokens from address
     * @param from Address to burn from
     * @param value Amount to burn
     */
    function burn(address from, uint256 value)
        external
        onlyRole(MINT_AND_BURN_ROLE)
        nonAddressZero(from)
        moreThanZero(value)
    {
        _burn(from, value);
    }

    function burn(uint256 value) public override onlyOwner moreThanZero(value) {
        uint256 balance = balanceOf(msg.sender);
        if (balance < value) {
            revert AbstraktGovernToken__BurnAmountExceedsBalance();
        }
        super.burn(value);
    }

    function transfer(address to, uint256 value)
        public
        override
        nonAddressZero(to)
        moreThanZero(value)
        returns (bool)
    {
        if (value == type(uint256).max) {
            value = balanceOf(msg.sender);
        }

        if (balanceOf(to) == 0) {
            s_accountInterestRate[to] = s_accountInterestRate[msg.sender];
        }

        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value)
        public
        override
        nonAddressZero(from)
        nonAddressZero(to)
        moreThanZero(value)
        returns (bool)
    {
        if (value == type(uint256).max) {
            value = balanceOf(from);
        }

        if (balanceOf(to) == 0) {
            s_accountInterestRate[to] = s_accountInterestRate[from];
        }

        return super.transferFrom(from, to, value);
    }

    function principalBalanceOf(address account) external view returns (uint256) {
        return super.balanceOf(account);
    }

    /*/////////////////////////////////////////////////////////////
                        GETTER FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getMintAndBurnRole() external pure returns (bytes32) {
        return MINT_AND_BURN_ROLE;
    }

    function getAccountInterestRate(address account) external view returns (uint256) {
        return s_accountInterestRate[account];
    }

    /*/////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////*/

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
