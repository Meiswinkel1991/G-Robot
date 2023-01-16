// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./interfaces/IERC20.sol";
import "./interfaces/protocol/ITradeHelper.sol";
import "./interfaces/protocol/IProjectSettings.sol";
import "./interfaces/IVault.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Router {
    struct BotSetting {
        address contractAddress;
        address owner;
        bool isActivated;
        uint8 leverage;
        uint256 tradeSize;
        uint256 gridSize;
        uint256 longLimitPrice;
        uint256 shortLimitPrice;
    }

    bytes32 public referralCode =
        0x4d53575f32303233000000000000000000000000000000000000000000000000;

    /*====== State Variables ====== */

    address private tradeHelperImplementation;
    address private projectSettings;

    bytes32[] private botKeys;
    mapping(bytes32 => BotSetting) private botSettings;
    mapping(address => address) private priceFeedAddresses;
    mapping(address => uint8) private priceFeedDecimals;

    /*====== Events ======*/
    event PriceFeedUpdated(address indexed token, address indexed priceFeed);

    event BotInitialized(bytes32 botKey, address indexToken, address owner);

    event BotActivated(
        bytes32 botKey,
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
        //1. Initial the Settings in the Router Contract

        bytes32 _botKey = getBotKey(
            msg.sender,
            _leverage,
            _stableToken,
            _indexToken
        );
        require(!_botExists(_botKey), "Router: Bot already exist");
        //2. Deploy a clone of the TradeHelper Base Contract
        address _newTradeHelper = _createNewTradeHelperContract();

        ITradeHelper(_newTradeHelper).initialize(
            projectSettings,
            _stableToken,
            _indexToken,
            referralCode
        );

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

        emit BotInitialized(_botKey, _indexToken, msg.sender);
    }

    function activateBot(bytes32 _botKey) public {
        require(_botExists(_botKey), "Router: Bot doesnt exist");
        BotSetting memory _setting = botSettings[_botKey];

        _isBotOwner(_botKey);
        _notActiveBot(_botKey);

        address _indexToken = ITradeHelper(_setting.contractAddress)
            .getIndexToken();

        _hasPriceFeed(_indexToken);

        botSettings[_botKey].longLimitPrice =
            getPrice(_indexToken) +
            _setting.gridSize;

        botSettings[_botKey].shortLimitPrice =
            getPrice(_indexToken) -
            _setting.gridSize;

        botSettings[_botKey].isActivated = true;

        emit BotActivated(
            _botKey,
            _indexToken,
            botSettings[_botKey].longLimitPrice,
            botSettings[_botKey].shortLimitPrice
        );
    }

    function closingAllPositions(bytes32 _botKey) external {
        require(_botExists(_botKey), "Router: Bot doesnt exist");
        BotSetting memory _setting = botSettings[_botKey];

        _isBotOwner(_botKey);
        _notActiveBot(_botKey);

        address _indexToken = ITradeHelper(_setting.contractAddress)
            .getIndexToken();

        address _stableToken = ITradeHelper(_setting.contractAddress)
            .getStableToken();

        IVault _vault = IVault(IProjectSettings(projectSettings).getVaultGMX());

        (uint256 size, uint256 col, , , , , , ) = _vault.getPosition(
            _setting.contractAddress,
            _stableToken,
            _indexToken,
            true
        );

        ITradeHelper(_setting.contractAddress).createDecreasePositionRequest(
            true,
            col,
            size
        );
    }

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

    function checkupKeep() external view returns (bool, bytes32) {
        //1. Check all bots if some limits are reached

        for (uint i = 0; i < botKeys.length; i++) {}
    }

    /*====== Internal Functions ======*/
    function _createNewTradeHelperContract() internal returns (address) {
        address _cloneContract = Clones.clone(tradeHelperImplementation);

        return _cloneContract;
    }

    function _isBotOwner(bytes32 _botKey) internal view {
        require(
            msg.sender == botSettings[_botKey].owner,
            "Router: Not the owner of the bot"
        );
    }

    function _notActiveBot(bytes32 _botKey) internal view {
        require(
            !botSettings[_botKey].isActivated,
            "Router: Bot already activated"
        );
    }

    function _botExists(bytes32 _botKey) internal view returns (bool) {
        for (uint i = 0; i < botKeys.length; i++) {
            if (_botKey == botKeys[i]) {
                return true;
            }
        }
        return false;
    }

    function _hasPriceFeed(address _token) internal view {
        require(
            priceFeedAddresses[_token] != address(0),
            "Router: No Price Feed initialized"
        );
    }

    function _checkLimitPrice(
        bytes32 _botKey
    ) internal view returns (bool, bool) {
        BotSetting memory _setting = botSettings[_botKey];

        address _token = ITradeHelper(botSettings[_botKey].contractAddress)
            .getStableToken();

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
