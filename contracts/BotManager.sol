// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./interfaces/IERC20.sol";
import "./interfaces/protocol/ITradeHelper.sol";
import "./interfaces/protocol/IProjectSettings.sol";
import "./interfaces/IVault.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract BotManager {
    struct BotSetting {
        address owner;
        bool isActivated;
        uint8 leverage;
        uint256 tradeSize;
        uint256 gridSize;
        uint256 longLimitPrice;
        uint256 shortLimitPrice;
    }

    struct PositionData {
        uint256 col;
        uint256 size;
        uint256 limitTrigger;
        uint256 exitPrice;
        bool long;
    }

    bytes32 public referralCode =
        0x4d53575f32303233000000000000000000000000000000000000000000000000;

    /*====== State Variables ====== */

    address private tradeHelperImplementation;
    address private projectSettings;

    address[] private bots;
    mapping(address => BotSetting) private botSettings;
    mapping(address => PositionData[]) private positionDatas;
    mapping(address => address) private priceFeedAddresses;
    mapping(address => uint8) private priceFeedDecimals;

    /*====== Events ======*/
    event PriceFeedUpdated(address indexed token, address indexed priceFeed);

    event BotInitialized(address botAddress, address indexToken, address owner);

    event BotActivated(
        address botAddress,
        address indexToken,
        uint256 longLimitOrder,
        uint256 shortLimitOrder
    );

    constructor() {}

    function setUpNewBot(
        address _stableToken,
        address _indexToken,
        uint8 _leverage,
        uint256 _gridSize,
        uint256 _tradingSize
    ) public {
        address _newTradeHelper = _createNewTradeHelperContract();

        ITradeHelper(_newTradeHelper).initialize(
            projectSettings,
            _stableToken,
            _indexToken,
            referralCode
        );

        bots.push(_newTradeHelper);

        BotSetting memory _newSetting = BotSetting(
            msg.sender,
            false,
            _leverage,
            _gridSize,
            _tradingSize,
            0,
            0
        );

        botSettings[_newTradeHelper] = _newSetting;

        emit BotInitialized(_newTradeHelper, _indexToken, msg.sender);
    }

    function activateBot(address _bot) public {
        require(_botExists(_bot), "BotManager: Bot doesnt exist");
        BotSetting memory _setting = botSettings[_bot];

        _isBotOwner(_bot);
        _notActiveBot(_bot);

        address _indexToken = ITradeHelper(_bot).getIndexToken();

        _hasPriceFeed(_indexToken);

        botSettings[_bot].longLimitPrice =
            getPrice(_indexToken) +
            _setting.gridSize;

        botSettings[_bot].shortLimitPrice =
            getPrice(_indexToken) -
            _setting.gridSize;

        botSettings[_bot].isActivated = true;

        emit BotActivated(
            _bot,
            _indexToken,
            botSettings[_bot].longLimitPrice,
            botSettings[_bot].shortLimitPrice
        );
    }

    function updatePositions(
        bool _increase,
        uint256 _limitTrigger,
        uint256 _col,
        uint256 _size
    ) external {
        _isBotContract();
    }

    /*====== Setup Functions ======*/

    function setPriceFeed(address _token, address _priceFeed) public {
        priceFeedAddresses[_token] = _priceFeed;

        emit PriceFeedUpdated(_token, _priceFeed);
    }

    function setTradeHelperImplemenation(address _implementation) external {
        tradeHelperImplementation = _implementation;
    }

    function setProjectSettingAddress(address _projectSettings) external {
        projectSettings = _projectSettings;
    }

    function setReferralCode(bytes32 _code) external {
        referralCode = _code;
    }

    /*====== Internal Functions ======*/
    function _createNewTradeHelperContract() internal returns (address) {
        address _cloneContract = Clones.clone(tradeHelperImplementation);

        return _cloneContract;
    }

    function _isBotOwner(address _bot) internal view {
        require(
            msg.sender == botSettings[_bot].owner,
            "BotManager: Not the owner of the bot"
        );
    }

    function _notActiveBot(address _bot) internal view {
        require(
            !botSettings[_bot].isActivated,
            "BotManager: Bot already activated"
        );
    }

    function _botExists(address _bot) internal view returns (bool) {
        for (uint i = 0; i < bots.length; i++) {
            if (_bot == bots[i]) {
                return true;
            }
        }
        return false;
    }

    function _isBotContract() internal view {
        bool _isBot;
        for (uint256 i = 0; i < bots.length; i++) {
            if (bots[i] == msg.sender) {
                _isBot = true;
            }
        }
        require(_isBot, "BotManager: Not a bot contract");
    }

    function _hasPriceFeed(address _token) internal view {
        require(
            priceFeedAddresses[_token] != address(0),
            "BotManager: No Price Feed initialized"
        );
    }

    function _checkLimitPrice(address _bot) internal view returns (bool, bool) {
        BotSetting memory _setting = botSettings[_bot];

        address _token = ITradeHelper(_bot).getStableToken();

        uint256 _price = getPrice(_token);

        bool limitsExceed = _price >= _setting.longLimitPrice ||
            _price <= _setting.shortLimitPrice
            ? true
            : false;

        if (limitsExceed) {
            bool long = _price >= _setting.longLimitPrice ? true : false;
            return (limitsExceed, long);
        }

        return (limitsExceed, false);
    }

    /*====== Pure / View Functions ====== */
    function getBotSetting(
        address _bot
    ) external view returns (BotSetting memory) {
        return botSettings[_bot];
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

    function getBotContracts() external view returns (address[] memory) {
        return bots;
    }

    function getPrice(address _token) public view returns (uint256) {
        AggregatorV3Interface _priceFeed = AggregatorV3Interface(
            priceFeedAddresses[_token]
        );

        (
            ,
            /*uint80 roundID*/ int price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = _priceFeed.latestRoundData();

        return uint256(price);
    }

    function getPriceFeed(address _token) external view returns (address) {
        return priceFeedAddresses[_token];
    }
}
