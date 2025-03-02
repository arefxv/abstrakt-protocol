// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IAbstraktGovernToken is IERC20 {
    function setInterestRate(uint256 newInterestRate) external;

    function grantMintAndBurnRole(address to) external;

    function mint(address to, uint256 value, uint256 accInterestRate) external;

    function mint(address to, uint256 value) external returns (bool);

    function burn(address from, uint256 value) external;

    function burn(uint256 amount) external;

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function principalBalanceOf(address _address) external view returns (uint256);

    function getInterestRate() external view returns (uint256);

    function getMintAndBurnRole() external pure returns (bytes32);

    function getAccountInterestRate(address account) external view returns (uint256);
}
