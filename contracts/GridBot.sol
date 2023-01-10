// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/IRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVault.sol";

contract GridBot {
    struct LimitOrder {
        address underlyingToken;
        bool isLong;
        uint256 assetPrice;
        uint8 leverage;
    }

    /* ====== State Variables ====== */

    address private tokenAddressUSDC;

    address private routerGMX;
    address private vaultGMX;

    LimitOrder[] public orders;

    constructor(
        address _routerGMX,
        address _vaultGMX,
        address _tokenAddressUSDC
    ) {
        routerGMX = _routerGMX;
        vaultGMX = _vaultGMX;
        tokenAddressUSDC = _tokenAddressUSDC;
    }

    receive() external payable {}

    /* ====== Main Functions ====== */
    function executeLimitOrder() external {}

    function openPosition(LimitOrder memory _order) public {
        uint256 _balance = IERC20(tokenAddressUSDC).balanceOf(address(this));

        uint256 _positionSize = _balance / 20;

        uint256 _price = IVault(vaultGMX).getMaxPrice(_order.underlyingToken);

        console.log(_price);

        address[] memory _path = new address[](1);

        _path[0] = tokenAddressUSDC;

        IRouter(routerGMX).increasePosition(
            _path,
            _order.underlyingToken,
            _positionSize,
            0,
            _positionSize * _order.leverage * 10 ** 30,
            _order.isLong,
            _price * 10 ** 30
        );
    }

    function addLimitOrder(
        address _underlyingToken,
        bool _isLong,
        uint256 _assetPrice,
        uint8 _leverage
    ) external {
        orders.push(
            LimitOrder(_underlyingToken, _isLong, _assetPrice, _leverage)
        );
    }

    /* ====== Internal Functions ====== */

    /* ====== Pure / View Functions ====== */

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getLimitOrder(
        uint8 orderId
    ) public view returns (LimitOrder memory) {
        return orders[orderId];
    }
}
