// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract Checkers {
    error InvalidAddress(address);
    error AmountMustBeMoreThanZero();
    error YouAreNotTheOwner();
    error SendMoreAmount(uint256);
    error InterestRateCanOnlyDecrease(uint256, uint256);

    modifier nonAddressZero(address _address) {
        if (_address == address(0)) {
            revert InvalidAddress(_address);
        }
        _;
    }

    modifier moreThanZero(uint256 value) {
        if (value == 0) {
            revert AmountMustBeMoreThanZero();
        }
        _;
    }

    modifier minAmount(uint256 value, uint256 minimumAmount) {
        if (value < minimumAmount) {
            revert SendMoreAmount(minimumAmount);
        }
        _;
    }

    modifier newInterestRate(uint256 _prevInterestRate, uint256 _newInterestRate) {
        if (_newInterestRate > _prevInterestRate) {
            revert InterestRateCanOnlyDecrease(_prevInterestRate, _newInterestRate);
        }
        _;
    }
}
