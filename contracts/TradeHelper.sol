// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/IPositionRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";

contract TradeHelper {
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
    address private stableTokenAddress;
    address private indexTokenAddress;

    address private vaultGMX;
    address private positionRouterGMX;
    address private routerGMX;

    /*====== State Variables ======*/
    bool private pluginApproved;
    uint8 private stableTokenDecimals;

    bytes32 private longPosition;
    bytes32 private shortPosition;

    PositionRequest private longPositionRequest;
    PositionRequest private shortPositionRequest;

    PositionData private longPositionData;
    PositionData private shortPositionData;

    /*====== Events ======*/
    event PositionRequestEdited(bytes32 positionKey, bool isExecuted);

    constructor(
        address _routerGMX,
        address _positionRouterGMX,
        address _vaultGMX,
        address _tokenAddressUSDC,
        address _indexTokenAddress,
        uint8 _stableTokenDecimals
    ) {
        stableTokenAddress = _tokenAddressUSDC;
        positionRouterGMX = _positionRouterGMX;
        vaultGMX = _vaultGMX;
        routerGMX = _routerGMX;

        indexTokenAddress = _indexTokenAddress;
        stableTokenDecimals = _stableTokenDecimals;
    }

    receive() external payable {}

    fallback() external payable {}

    /*====== Main Functions ======*/

    function createIncreasePositionRequest(
        uint256 _amountIn,
        uint256 _positionSize,
        bool _isLong
    ) public {
        // 1. approvePlugin
        _approveRouterPlugin();

        // 2. approve router contract with the collateral token
        _approveRouterForTokenTransfer(_amountIn);

        // 3. create a increase position with positionRouter
        _createIncreasePositionRequest(_amountIn, _positionSize, _isLong);
    }

    function createDecreasePositionRequest(
        uint256 _amountOut,
        uint256 _sizeDelta,
        bool _isLong
    ) public {
        _createDecreasePositionRequest(_amountOut, _sizeDelta, _isLong);
    }

    function executePosition(bool _isLong) public {
        bool isExecuted = _isLong
            ? longPositionRequest.executed
            : shortPositionRequest.executed;

        require(!isExecuted, "Last Request already executed");

        //TODO: check if liquid amount of GMX is enough
        // guaranteedUSD(token):vault + size < maxGlobalLongSize: positionRouter

        uint256 amountNeeded = IVault(vaultGMX).guaranteedUsd(
            indexTokenAddress
        );
        console.log(amountNeeded);
        uint256 amountAvailable = IPositionRouter(positionRouterGMX)
            .maxGlobalLongSizes(indexTokenAddress);
        console.log(amountAvailable);

        bytes32 _key = _isLong ? longPosition : shortPosition;
        IPositionRouter(positionRouterGMX).executeIncreasePosition(
            _key,
            payable(address(this))
        );
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
        uint256 _amountIn,
        uint256 _positionSize,
        bool _isLong
    ) internal {
        uint256 _price = IVault(vaultGMX).getMaxPrice(indexTokenAddress);

        uint8 counter = 1;
        if (_isLong) {
            counter = 2;
        }
        address[] memory _path = new address[](counter);

        _path[0] = stableTokenAddress;

        if (_isLong) {
            _path[1] = indexTokenAddress;
        }

        uint256 _executionFee = IPositionRouter(positionRouterGMX)
            .minExecutionFee();

        uint256 _size = _positionSize * 10 ** (30 - stableTokenDecimals);

        bytes32 positionKey = IPositionRouter(positionRouterGMX)
            .createIncreasePosition{value: _executionFee}(
            _path,
            indexTokenAddress,
            _amountIn,
            0,
            _size,
            _isLong,
            _price,
            _executionFee,
            bytes32(0),
            address(this)
        );

        if (_isLong) {
            _updateLongPosition(positionKey, _price, _amountIn, _size, true);
        } else {
            _updateShortPosition(positionKey, _price, _amountIn, _size, true);
        }
    }

    function _createDecreasePositionRequest(
        uint256 _amountOut,
        uint256 _sizeDelta,
        bool _isLong
    ) internal {
        address[] memory _path = new address[](2);

        _path[0] = indexTokenAddress;
        _path[1] = stableTokenAddress;

        uint256 _executionFee = IPositionRouter(positionRouterGMX)
            .minExecutionFee();

        uint256 _price = IVault(vaultGMX).getMinPrice(indexTokenAddress);

        uint256 _size = _sizeDelta * 10 ** (30 - stableTokenDecimals);

        bytes32 positionKey = IPositionRouter(positionRouterGMX)
            .createDecreasePosition{value: _executionFee}(
            _path,
            indexTokenAddress,
            _amountOut,
            _size,
            _isLong,
            address(this),
            _price,
            0,
            _executionFee,
            false,
            address(this)
        );

        if (_isLong) {
            _updateLongPosition(positionKey, _price, _amountOut, _size, false);
        } else {
            _updateShortPosition(positionKey, _price, _amountOut, _size, false);
        }
    }

    function _updateLongPosition(
        bytes32 positionKey,
        uint256 _price,
        uint256 _amountIn,
        uint256 _size,
        bool _increase
    ) internal {
        if (longPosition == bytes32(0)) {
            longPosition = positionKey;
        }
        longPositionRequest = PositionRequest(
            _price,
            _amountIn,
            _size,
            false,
            _increase
        );
    }

    function _updateShortPosition(
        bytes32 positionKey,
        uint256 _price,
        uint256 _amountIn,
        uint256 _size,
        bool _increase
    ) internal {
        if (shortPosition == bytes32(0)) {
            shortPosition = positionKey;
        }
        shortPositionRequest = PositionRequest(
            _price,
            _amountIn,
            _size,
            false,
            _increase
        );
    }

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(routerGMX).approvePlugin(positionRouterGMX);
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer(uint256 _amount) internal {
        uint256 _allowance = IERC20(stableTokenAddress).allowance(
            address(this),
            routerGMX
        );

        if (_allowance < _amount) {
            require(IERC20(stableTokenAddress).approve(routerGMX, _amount));
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
