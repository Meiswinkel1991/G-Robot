// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/protocol/IProjectSettings.sol";

import "./interfaces/IPositionRouter.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract TradeHelper is Initializable {
    struct PositionData {
        uint256 amount;
        uint256 entryPrice;
        uint256 size;
        uint256 exitPrice;
        bool isLong;
    }

    struct PositionRequest {
        uint256 entryPrice;
        uint256 amount;
        uint256 size;
        bool executed;
        bool increase;
    }

    /*====== GMX Addresses ======*/
    address private projectSettings;

    address private stableTokenAddress;
    address private indexTokenAddress;

    /*====== State Variables ======*/
    bool private pluginApproved;

    bytes32 private longPosition;
    bytes32 private shortPosition;

    PositionRequest private longPositionRequest;
    PositionRequest private shortPositionRequest;

    PositionData private longPositionData;
    PositionData private shortPositionData;

    /*====== Events ======*/
    event PositionRequestEdited(bytes32 positionKey, bool isExecuted);
    event UpdateBotSetting(
        uint8 leverage,
        uint256 tradingSize,
        uint256 gridSize
    );
    event BotStarted(uint256 longLimitPrice, uint256 shortLimitPrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _projectSettings,
        address _tokenAddressUSDC,
        address _indexTokenAddress
    ) public initializer {
        projectSettings = _projectSettings;
        stableTokenAddress = _tokenAddressUSDC;
        indexTokenAddress = _indexTokenAddress;
    }

    receive() external payable {}

    fallback() external payable {}

    /*====== Main Functions ======*/

    function createIncreasePositionRequest(
        bool _isLong,
        uint256 _amountIn,
        uint256 _deltaSize
    ) public {
        // 1. approvePlugin
        _approveRouterPlugin();

        // 2. approve router contract with the collateral token
        _approveRouterForTokenTransfer(_amountIn);

        // 3. create a increase position with positionRouter
        _createIncreasePositionRequest(_isLong, _amountIn, _deltaSize);
    }

    function createDecreasePositionRequest(
        bool _isLong,
        uint256 _amountOut,
        uint256 _deltaSize
    ) public {
        _createDecreasePositionRequest(_isLong, _amountOut, _deltaSize);
    }

    function executePosition(bool _isLong) public {
        bool isExecuted = _isLong
            ? longPositionRequest.executed
            : shortPositionRequest.executed;

        require(!isExecuted, "Last Request already executed");

        //TODO: check if liquid amount of GMX is enough
        // guaranteedUSD(token):vault + size < maxGlobalLongSize: positionRouter

        uint256 amountNeeded = IVault(
            IProjectSettings(projectSettings).getVaultGMX()
        ).guaranteedUsd(indexTokenAddress);

        uint256 amountAvailable = IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).maxGlobalLongSizes(indexTokenAddress);

        bytes32 _key = _isLong ? longPosition : shortPosition;
        IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).executeIncreasePosition(_key, payable(address(this)));
    }

    function gmxPositionCallback(
        bytes32 positionKey,
        bool isExecuted,
        bool /* */
    ) public {
        if (longPosition == positionKey) {
            longPositionRequest.executed = isExecuted;
        } else {
            shortPositionRequest.executed = isExecuted;
        }

        emit PositionRequestEdited(positionKey, isExecuted);
    }

    /*====== Internal Functions ======*/

    function _createIncreasePositionRequest(
        bool _isLong,
        uint256 _amountIn,
        uint256 _deltaSize
    ) internal {
        uint256 _price = IVault(IProjectSettings(projectSettings).getVaultGMX())
            .getMaxPrice(indexTokenAddress);

        uint8 counter = 1;
        if (_isLong) {
            counter = 2;
        }
        address[] memory _path = new address[](counter);

        _path[0] = stableTokenAddress;

        if (_isLong) {
            _path[1] = indexTokenAddress;
        }

        uint256 _executionFee = IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).minExecutionFee();

        bytes32 positionKey = IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).createIncreasePosition{value: _executionFee}(
            _path,
            indexTokenAddress,
            _amountIn,
            0,
            _deltaSize,
            _isLong,
            _price,
            _executionFee,
            bytes32(0),
            address(this)
        );

        if (_isLong) {
            _updateLongPosition(
                positionKey,
                _price,
                _amountIn,
                _deltaSize,
                true
            );
        } else {
            _updateShortPosition(
                positionKey,
                _price,
                _amountIn,
                _deltaSize,
                true
            );
        }
    }

    function _createDecreasePositionRequest(
        bool _isLong,
        uint256 _amountOut,
        uint256 _deltaSize
    ) internal {
        address[] memory _path = new address[](2);

        _path[0] = indexTokenAddress;
        _path[1] = stableTokenAddress;

        uint256 _executionFee = IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).minExecutionFee();

        uint256 _price = IVault(IProjectSettings(projectSettings).getVaultGMX())
            .getMinPrice(indexTokenAddress);

        bytes32 positionKey = IPositionRouter(
            IProjectSettings(projectSettings).getPositionRouterGMX()
        ).createDecreasePosition{value: _executionFee}(
            _path,
            indexTokenAddress,
            _amountOut,
            _deltaSize,
            _isLong,
            address(this),
            _price,
            0,
            _executionFee,
            false,
            address(this)
        );

        if (_isLong) {
            _updateLongPosition(
                positionKey,
                _price,
                _amountOut,
                _deltaSize,
                false
            );
        } else {
            _updateShortPosition(
                positionKey,
                _price,
                _amountOut,
                _deltaSize,
                false
            );
        }
    }

    function _updateLongPosition(
        bytes32 positionKey,
        uint256 _price,
        uint256 _amount,
        uint256 _size,
        bool _increase
    ) internal {
        if (longPosition == bytes32(0)) {
            longPosition = positionKey;
        }
        longPositionRequest = PositionRequest(
            _price,
            _amount,
            _size,
            false,
            _increase
        );
    }

    function _updateShortPosition(
        bytes32 positionKey,
        uint256 _price,
        uint256 _amount,
        uint256 _size,
        bool _increase
    ) internal {
        if (shortPosition == bytes32(0)) {
            shortPosition = positionKey;
        }
        shortPositionRequest = PositionRequest(
            _price,
            _amount,
            _size,
            false,
            _increase
        );
    }

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(IProjectSettings(projectSettings).getRouterGMX())
                .approvePlugin(
                    IProjectSettings(projectSettings).getPositionRouterGMX()
                );
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer(uint256 _tokenAmount) internal {
        uint256 _allowance = IERC20(stableTokenAddress).allowance(
            address(this),
            IProjectSettings(projectSettings).getRouterGMX()
        );

        if (_allowance < _tokenAmount) {
            require(
                IERC20(stableTokenAddress).approve(
                    IProjectSettings(projectSettings).getRouterGMX(),
                    _tokenAmount
                )
            );
        }
    }

    /**
     * @dev - update all detailed legs of one position. Remove or add the leg to the list.
     */
    function _updateLegsOfPosition() internal {}

    /*====== Pure / View Functions ======*/

    function getPositionKey(bool _isLong) external view returns (bytes32) {
        return _isLong ? longPosition : shortPosition;
    }

    function getlastPositionRequest(
        bool _isLong
    ) external view returns (PositionRequest memory) {
        return _isLong ? longPositionRequest : shortPositionRequest;
    }
}
