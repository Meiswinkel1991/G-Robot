// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./interfaces/IERC20.sol";
import "./interfaces/protocol/ITradeHelper.sol";
import "./interfaces/protocol/IProjectSettings.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Router {
    struct BotSetting {
        address contractAddress;
        address owner;
        bool isAcitvated;
        uint8 leverage;
        uint256 tradeSize;
        uint256 gridSize;
        uint256 longLimitPrice;
        uint256 shortLimitPrice;
    }

    /*====== State Variables ====== */

    address private tradeHelperImplementation;
    address private projectSettings;

    bytes32[] private botKeys;
    mapping(bytes32 => BotSetting) private botSettings;
    mapping(address => address) private priceFeedAddresses;

    /*====== Modifier ======*/
    modifier hasPriceFeedAddress(address _token) {
        require(
            priceFeedAddresses[_token] != address(0),
            "Router: No Price Feed initialized"
        );
        _;
    }

    /*====== Events ======*/
    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event BotInitialized(
        address indexed helperAddress,
        address indexed owner,
        address indexToken,
        uint8 leverage
    );

    constructor() {}

    function setUpNewBot(
        address _stableToken,
        address _indexToken,
        uint8 _leverage,
        uint256 _gridSize,
        uint256 _tradingSize
    ) public {
        //2. Initial the Settings in the Router Contract

        bytes32 _botKey = getBotKey(
            msg.sender,
            _leverage,
            _stableToken,
            _indexToken
        );

        //1. Deploy a clone of the TradeHelper Base Contract
        address _newTradeHelper = _createNewTradeHelperContract();

        ITradeHelper(_newTradeHelper).initialize(
            projectSettings,
            _stableToken,
            _indexToken
        );

        //TODO: Check if a similar bot is already open

        BotSetting memory _newSetting = BotSetting(
            _newTradeHelper,
            msg.sender,
            false,
            _leverage,
            _gridSize,
            _tradingSize,
            0,
            0
        );

        botKeys.push(_botKey);

        botSettings[_botKey] = _newSetting;
    }

    function activateBot(uint _id) public {}

    function setPriceFeed(address _token, address _priceFeed) public {
        priceFeedAddresses[_token] = _priceFeed;
    }

    function setTradeHelperImplemenation(address _implementation) external {
        tradeHelperImplementation = _implementation;
    }

    function setProjectSettingAddress(address _projectSettings) external {
        projectSettings = _projectSettings;
    }

    function checkupKeep() external view returns (bool, bytes32) {}

    /*====== Internal Functions ======*/
    function _createNewTradeHelperContract() internal returns (address) {
        address _cloneContract = Clones.clone(tradeHelperImplementation);

        return _cloneContract;
    }

    function _isBotOwner(bytes32 _botKey, address _sender) internal view {
        require(
            _sender == botSettings[_botKey].owner,
            "Router: Not the owner of the bot"
        );
    }

    /*====== Pure / View Functions ====== */
    function getBotSetting(
        bytes32 _botKey
    ) external view returns (BotSetting memory) {
        return botSettings[_botKey];
    }

    function getBotKey(
        address owner,
        uint8 leverage,
        address stableToken,
        address indexToken
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(owner, leverage, stableToken, indexToken)
            );
    }

    function getBotKeyList() external view returns (bytes32[] memory) {
        return botKeys;
    }
}
