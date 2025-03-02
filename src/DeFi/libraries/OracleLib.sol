// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink-brownie/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answerdInRound) =
            chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answerdInRound < roundId) {
            revert OracleLib__StalePrice();
        }

        uint256 secondSince = block.timestamp - updatedAt;
        if (secondSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answerdInRound);
    }

    function getTimeout(AggregatorV3Interface /* chainlinkFeed */ ) public pure returns (uint256) {
        return TIMEOUT;
    }
}
