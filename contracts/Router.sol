// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./interfaces/IERC20.sol";

contract Router {
    struct BotSetting {
        address contractAddress;
        address owner;
        bool isAcitvated;
    }

    /*====== State Variables ====== */

    BotSetting[] private gridBots;

    mapping(address => address) private priceFeedAddresses;

    /*====== Modifier ======*/
    modifier hasPriceFeedAddress(address _token) {
        require(
            priceFeedAddresses[_token] != address(0),
            "Router: No Price Feed initialized"
        );
        _;
    }

    constructor() {}

    function setUpNewBot(
        address _routerGMX,
        address _positionRouterGMX,
        address _vaultGMX,
        address _tokenAddressUSDC,
        address _indexTokenAddress,
        uint8 _stableTokenDecimals,
        uint8 leverage,
        uint256 gridSize,
        uint256 tradingShare,
        uint256 tradingSize
    ) public {}

    function activateBot(uint _id) public {}

    function checkupKeep() external view returns (bool, bytes32) {
        for (uint i = 0; i < gridBots.length; i++) {}
    }

    /*====== Internal Functions ======*/
    function _isBotOwner(address _sender, uint256 _id) internal view {
        require(
            _sender == gridBots[_id].owner,
            "Router: Not the owner of the bot"
        );
    }

    function _checkBotActions(uint _id) internal view returns (bool) {
        return false;
    }

    /*====== Pure / View Functions ====== */
    function getBotSetting(uint _id) external view returns (BotSetting memory) {
        return gridBots[_id];
    }
}
