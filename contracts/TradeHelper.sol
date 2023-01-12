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
    struct PositionRequest {
        uint256 entryPrice;
        uint256 amount;
        uint256 size;
        bool executed;
        bool increase;
    }

    /*====== GMX Addresses ======*/
    address private tokenAddressUSDC;

    address private vaultGMX;
    address private positionRouterGMX;
    address private routerGMX;

    /*====== State Variables ======*/
    bool private pluginApproved;

    bytes32[] private positions;

    mapping(bytes32 => PositionRequest) private lastPositionRequests;

    /*====== Events ======*/
    event PositionRequestEdited(bytes32 positionKey, bool isExecuted);

    constructor(
        address _positionRouterGMX,
        address _vaultGMX,
        address _tokenAddressUSDC
    ) {
        tokenAddressUSDC = _tokenAddressUSDC;
        positionRouterGMX = _positionRouterGMX;
        vaultGMX = _vaultGMX;
    }

    receive() external payable {}

    /*====== Main Functions ======*/

    function createIncreasePositionRequest(
        address _indexToken,
        uint256 _amountIn,
        uint256 _positionSize,
        bool _isLong
    ) public {
        // 1. approvePlugin
        _approveRouterPlugin();

        // 2. approve router contract with the collateral token
        _approveRouterForTokenTransfer(_amountIn);

        // 3. create a increase position with positionRouter

        uint256 _price = IVault(vaultGMX).getMaxPrice(_indexToken);

        bytes32 _reveralCode;

        address[] memory _path = new address[](2);

        _path[0] = tokenAddressUSDC;
        _path[1] = _indexToken;

        uint256 _executionFee = IPositionRouter(positionRouterGMX)
            .minExecutionFee();

        console.log(_price);

        bytes32 positionKey = IPositionRouter(positionRouterGMX)
            .createIncreasePosition(
                _path,
                _indexToken,
                _amountIn,
                0,
                _positionSize * 10 ** 24,
                _isLong,
                _price,
                _executionFee,
                _reveralCode,
                address(this)
            );

        lastPositionRequests[positionKey] = PositionRequest(
            _price,
            _amountIn,
            _positionSize * 10 ** 24,
            false,
            true
        );
    }

    function createDecreaseRequest(
        address _indexToken,
        uint256 _amountOut,
        uint256 _sizeDelta,
        bool _isLong
    ) public {
        address[] memory _path = new address[](2);

        _path[0] = _indexToken;
        _path[1] = tokenAddressUSDC;

        uint256 _executionFee = IPositionRouter(positionRouterGMX)
            .minExecutionFee();

        uint256 _price = IVault(vaultGMX).getMinPrice(_indexToken);

        bytes32 positionKey = IPositionRouter(positionRouterGMX)
            .createDecreasePosition(
                _path,
                _indexToken,
                _amountOut,
                _sizeDelta * 10 ** 24,
                _isLong,
                address(this),
                _price,
                0,
                _executionFee,
                false,
                address(this)
            );

        lastPositionRequests[positionKey] = PositionRequest(
            _price,
            _amountOut,
            _sizeDelta * 10 ** 24,
            false,
            false
        );
    }

    function executePosition(bytes32 key) public {
        bool isExecuted = lastPositionRequests[key].executed;

        require(!isExecuted, "Last Request already executed");

        IPositionRouter(positionRouterGMX).executeIncreasePosition(
            key,
            payable(address(this))
        );
    }

    function gmxPositionCallback(
        bytes32 positionKey,
        bool isExecuted,
        bool /* */
    ) public {
        lastPositionRequests[positionKey].executed = isExecuted;

        emit PositionRequestEdited(positionKey, isExecuted);
    }

    /*====== Internal Functions ======*/

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(routerGMX).approvePlugin(positionRouterGMX);
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer(uint256 _amount) internal {
        uint256 _allowance = IERC20(tokenAddressUSDC).allowance(
            address(this),
            routerGMX
        );

        if (_allowance < _amount) {
            require(IERC20(tokenAddressUSDC).approve(routerGMX, _amount));
        }
    }

    /*====== Pure / View Functions ======*/
}
