// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/IPositionRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";

contract GridBot {
    struct Position {
        address collateralToken;
        address indexToken;
        bool isLong;
        uint256 lastChange;
        bytes32 key;
    }

    uint256 constant EXECUTION_FEE = 100000000000000;
    uint256 constant PRICE_MULTIPLIER = 10 ** 30;
    uint256 constant MAX = type(uint256).max;
    uint8 constant MIN_TIME_DELAY = 180;

    /* ====== State Variables ====== */
    bool private pluginApproved;

    Position[] private positions;

    address private tokenAddressUSDC; //USDC Token only have 6 Decimals!!!
    address private tokenAddressWETH;

    address private vaultGMX;
    address private positionRouterGMX;
    address private routerGMX;

    constructor(
        address _positionRouterGMX,
        address _vaultGMX,
        address _routerGMX,
        address _tokenAddressUSDC,
        address _tokenAddressWETH
    ) {
        positionRouterGMX = _positionRouterGMX;
        vaultGMX = _vaultGMX;
        routerGMX = _routerGMX;
        tokenAddressUSDC = _tokenAddressUSDC;
        tokenAddressWETH = _tokenAddressWETH;
    }

    receive() external payable {}

    /* ====== Main Functions ====== */

    function addToPosition(
        uint256 _amoutIn,
        uint256 _sizeDelta
    ) public returns (bytes32) {
        // 1. approvePlugin router

        _approveRouterPlugin();

        // 2. approve router contract with the collateral token

        _approveRouterForTokenTransfer();

        // 3. createIncreasePosition with positionRouter

        uint256 _price = IVault(vaultGMX).getMaxPrice(tokenAddressWETH);

        address[] memory path = new address[](2);

        bytes32 reveralCode;

        path[0] = tokenAddressUSDC;
        path[1] = tokenAddressWETH;

        console.log(_price);

        bytes32 trxKey = IPositionRouter(positionRouterGMX)
            .createIncreasePosition{value: EXECUTION_FEE}(
            path,
            tokenAddressWETH,
            _amoutIn,
            0,
            _sizeDelta * 10 ** 24, //TODO: Code the correct leverage
            true,
            _price,
            EXECUTION_FEE,
            reveralCode,
            address(0)
        );
        if (!_isExistingPosition(trxKey)) {
            positions.push(
                Position(
                    tokenAddressWETH,
                    tokenAddressWETH,
                    true,
                    block.timestamp,
                    trxKey
                )
            );
        } else {
            uint16 _id = getPositionIndex(trxKey);
            positions[_id].lastChange = block.timestamp;
        }

        return trxKey;
    }

    function removeFromPosition() public {}

    function executePosition(bytes32 key) public {
        uint16 _id = getPositionIndex(key);

        require(!_isExecuted(_id), "Already exicuted");

        bool success = IPositionRouter(positionRouterGMX)
            .executeIncreasePosition(key, payable(address(this)));
        require(success, "Executuion failed");

        positions[_id].lastChange = block.timestamp;
    }

    function gmxPositionCallback(
        bytes32 positionKey,
        bool isExecuted,
        bool isIncrease
    ) public {}

    /* ====== Internal Functions ====== */

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(routerGMX).approvePlugin(positionRouterGMX);
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer() internal {
        require(IERC20(tokenAddressUSDC).approve(routerGMX, MAX));
    }

    function _isExistingPosition(bytes32 _key) internal view returns (bool) {
        for (uint8 i = 0; i < positions.length; i++) {
            Position memory pos = positions[i];
            if (_key == pos.key) {
                return true;
            }
        }
        return false;
    }

    function _isExecuted(uint16 _id) internal view returns (bool) {
        (, , , , , , , uint256 lastIncreaseTime) = getPositionInfo(_id);
        if (positions[_id].lastChange <= lastIncreaseTime) {
            console.log(lastIncreaseTime);
            return true;
        }
        return false;
    }

    /* ====== Pure / View Functions ====== */

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTrxKey(uint256 _positionIndex) public view returns (bytes32) {
        return positions[_positionIndex].key;
    }

    function getTokenDecimals(address _token) public view returns (uint256) {
        return IERC20Metadata(_token).decimals();
    }

    function getPositions() external view returns (Position[] memory) {
        return positions;
    }

    function getPositionIndex(bytes32 _key) public view returns (uint16) {
        for (uint16 i = 0; i < positions.length; i++) {
            Position memory pos = positions[i];
            if (_key == pos.key) {
                return i;
            }
        }
        return uint16(positions.length);
    }

    function getPositionInfo(
        uint256 _id
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        )
    {
        return
            IVault(vaultGMX).getPosition(
                address(this),
                positions[_id].collateralToken,
                positions[_id].indexToken,
                positions[_id].isLong
            );
    }

    function getTradeInfo(
        uint256 _id
    ) external view returns (uint256, uint256, bool) {
        uint256 _leverage = IVault(vaultGMX).getPositionLeverage(
            address(this),
            positions[_id].collateralToken,
            positions[_id].indexToken,
            positions[_id].isLong
        );

        (
            uint256 _size,
            ,
            uint256 _avgPrice,
            ,
            ,
            ,
            ,
            uint256 _lastIncreasedTimestamp
        ) = IVault(vaultGMX).getPosition(
                address(this),
                positions[_id].collateralToken,
                positions[_id].indexToken,
                positions[_id].isLong
            );

        (bool _hasProfit, uint256 _delta) = IVault(vaultGMX).getDelta(
            positions[_id].indexToken,
            _size,
            _avgPrice,
            positions[_id].isLong,
            _lastIncreasedTimestamp
        );

        return (_leverage, _delta, _hasProfit);
    }
}
