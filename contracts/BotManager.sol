// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "hardhat/console.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/protocol/ITradeHelper.sol";
import "./interfaces/protocol/IProjectSettings.sol";
import "./interfaces/IVault.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract BotManager is AutomationCompatible {
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
        uint256 entryPrice;
        uint256 exitPrice;
        bool long;
    }

    /** The minimum amount of bot funds when activated
     *  >>> tradingsize * MIN_FUND_MULTIPLIER <= funds  <<<
     * */
    uint8 public constant MIN_FUND_MULTIPLIER = 10;

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

    event PositionOpened(
        address bot,
        uint256 limit,
        uint256 collateral,
        uint256 positionSize
    );

    constructor() {}

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev - deploy a new bot and initialize it
     * @param _stableToken - the underlying token address (USDC,USDT,DAI)
     * @param _indexToken - the token to be traded (wBTC,wETH...)
     * @param _leverage - which leverage one chooses. The value must be above 1
     * @param _gridSize -the distance at which the limits are set. the decimals must match the chainlink pricefeed.
     * @param _tradingSize - the size of a single position size. the value must not be greater than one tenth of the total stable token balance.
     */
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
            _tradingSize,
            _gridSize,
            0,
            0
        );

        botSettings[_newTradeHelper] = _newSetting;

        emit BotInitialized(_newTradeHelper, _indexToken, msg.sender);
    }

    function activateBot(address _bot) public {
        _isBotContract(_bot);
        BotSetting memory _setting = botSettings[_bot];

        _isBotOwner(_bot);
        _notActiveBot(_bot);

        _validateBotFunds(_bot);

        address _indexToken = ITradeHelper(_bot).getIndexToken();
        _validatePriceFeed(_indexToken);

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

    function performUpkeep(bytes calldata performData) external override {
        address[] memory botList = abi.decode(performData, (address[]));

        for (uint256 i = 0; i < botList.length; i++) {
            ITradeHelper _bot = ITradeHelper(botList[i]);

            uint256 _price = getPrice(_bot.getIndexToken());

            // (bool _takeProfit, uint256 _positionId) = _checkForProfitTarget(
            //     botList[i],
            //     _price
            // );

            // if (_takeProfit) {}

            uint256 _balanceStable = IERC20(_bot.getStableToken()).balanceOf(
                botList[i]
            );

            if (_balanceStable >= botSettings[botList[i]].tradeSize) {
                if (botSettings[botList[i]].longLimitPrice <= _price) {
                    _bot.swapToIndexToken(botSettings[botList[i]].tradeSize);

                    _bot.createLongPosition{value: _bot.getExecutionFee()}(
                        botSettings[botList[i]].leverage,
                        botSettings[botList[i]].longLimitPrice
                    );
                }
                if (botSettings[botList[i]].shortLimitPrice >= _price) {}
            }
        }
    }

    function updatePosition(
        uint256 _limitTrigger,
        uint256 _size,
        uint256 _col,
        uint256 _price,
        bool _isLong
    ) external {
        _isBotContract(msg.sender);

        BotSetting memory _setting = botSettings[msg.sender];

        uint256 _exitPrice = _limitTrigger + _setting.gridSize;

        PositionData memory _newData = PositionData(
            _col,
            _size,
            _limitTrigger,
            _price,
            _exitPrice,
            _isLong
        );

        positionDatas[msg.sender].push(_newData);

        if (_isLong) {
            botSettings[msg.sender].longLimitPrice += _setting.gridSize;
            botSettings[msg.sender].shortLimitPrice += _setting.gridSize;
        } else {
            botSettings[msg.sender].shortLimitPrice -= _setting.gridSize;
            botSettings[msg.sender].longLimitPrice -= _setting.gridSize;
        }

        emit PositionOpened(msg.sender, _limitTrigger, _col, _size);
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

    function _isBotContract(address _botAddress) internal view {
        bool _isBot;
        for (uint256 i = 0; i < bots.length; i++) {
            if (bots[i] == _botAddress) {
                _isBot = true;
            }
        }
        require(_isBot, "BotManager: Not a bot contract");
    }

    function _validatePriceFeed(address _token) internal view {
        require(
            priceFeedAddresses[_token] != address(0),
            "BotManager: No Price Feed initialized"
        );
    }

    function _validateBotFunds(address _bot) internal view {
        address _stableToken = ITradeHelper(_bot).getStableToken();

        uint256 _funds = IERC20(_stableToken).balanceOf(_bot);

        require(
            _funds >= MIN_FUND_MULTIPLIER * botSettings[_bot].tradeSize,
            "BotManager: Bot has not enough funds"
        );
    }

    function _checkForActivePositions(
        address _bot,
        uint256 _shortLimit,
        uint256 _longLimit
    ) internal view returns (bool) {
        PositionData[] memory _positions = positionDatas[_bot];

        for (uint256 i = 0; i < _positions.length; i++) {
            uint256 _price = _positions[i].long ? _longLimit : _shortLimit;
            if (_price == _positions[i].limitTrigger) {
                return true;
            }
        }
        return false;
    }

    function _checkForProfitTarget(
        address _bot,
        uint256 _price
    ) internal view returns (bool takeProfit, uint256) {
        PositionData[] memory _positions = positionDatas[_bot];

        for (uint256 i = 0; i < _positions.length; i++) {
            bool _profit = _positions[i].long
                ? _price >= _positions[i].exitPrice
                : _price <= _positions[i].exitPrice;

            if (_profit) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /*====== Pure / View Functions ====== */

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 counter;

        for (uint256 i = 0; i < bots.length; i++) {
            address _bot = bots[i];
            BotSetting memory _setting = botSettings[_bot];
            bool _startLongPosition = getPrice(
                ITradeHelper(_bot).getIndexToken()
            ) > _setting.longLimitPrice;
            bool _startShortPosition = getPrice(
                ITradeHelper(_bot).getIndexToken()
            ) < _setting.shortLimitPrice;
            bool _activePositions = _checkForActivePositions(
                _bot,
                _setting.shortLimitPrice,
                _setting.longLimitPrice
            );
            if (
                (_startLongPosition || _startShortPosition) &&
                _setting.isActivated &&
                !_activePositions
            ) {
                counter++;
                upkeepNeeded = true;
            }
        }

        uint256 indexPosition;
        address[] memory updateableBots = new address[](counter);

        for (uint256 i = 0; i < bots.length; i++) {
            address _bot = bots[i];
            BotSetting memory _setting = botSettings[_bot];
            bool _startLongPosition = getPrice(
                ITradeHelper(_bot).getIndexToken()
            ) > _setting.longLimitPrice;
            bool _startShortPosition = getPrice(
                ITradeHelper(_bot).getIndexToken()
            ) < _setting.shortLimitPrice;
            bool _activePositions = _checkForActivePositions(
                _bot,
                _setting.shortLimitPrice,
                _setting.longLimitPrice
            );
            if (
                (_startLongPosition || _startShortPosition) &&
                _setting.isActivated &&
                !_activePositions
            ) {
                updateableBots[indexPosition] = _bot;
                indexPosition++;
            }
        }

        performData = abi.encode(updateableBots);
    }

    function getBotSetting(
        address _bot
    ) external view returns (BotSetting memory) {
        return botSettings[_bot];
    }

    function getBotList() external view returns (address[] memory) {
        return bots;
    }

    function getBotPositions(
        address _bot
    ) external view returns (PositionData[] memory) {
        return positionDatas[_bot];
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
