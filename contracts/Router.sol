// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Router {
    struct BotSetting {
        uint8 leverage;
        uint8 stableTokenDecimals;
        address stableTokenAddress;
        address indexToken;
        uint256 gridSize;
        uint256 tradingShare;
        uint256 tradingSize;
    }

    enum BotStrategy {
        ONLY_LONG,
        ONLY_SHORT,
        BOTH_AT_SAME,
        BOTH
    }

    /*====== State Variables ====== */

    BotSetting[] private gridBots;

    bool[] private activatedStrategies;

    constructor() {}

    function setUpNewBot() public {}

    /*====== Pure / View Functions ====== */
    function getBotSetting(uint _id) external view returns (BotSetting memory) {
        return gridBots[_id];
    }
}
