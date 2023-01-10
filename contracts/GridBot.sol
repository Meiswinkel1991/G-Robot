// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/IPositionRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";

contract GridBot {
    uint256 constant EXECUTION_FEE = 100000000000000;

    /* ====== State Variables ====== */

    address private tokenAddressUSDC;
    address private tokenAddressWETH;

    address private vaultGMX;
    address private positionRouterGMX;
    address private routerGMX;

    bytes32 private trxKey;

    bool private pluginApproved;

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
    function executeLimitOrder() external {}

    function openPosition() public {
        // 1. approvePlugin router

        _approveRouterPlugin();

        // 2. approve router contract with the colletarel token

        uint256 _balance = IERC20(tokenAddressUSDC).balanceOf(address(this));

        _approveRouterForTokenTransfer(_balance);

        // 3. createIncreasePosition with positionRouter

        uint256 _positionSize = _balance / 20;

        uint256 _price = IVault(vaultGMX).getMaxPrice(tokenAddressWETH);

        address[] memory path = new address[](1);

        bytes32 reveralCode;

        path[0] = tokenAddressUSDC;

        console.log(_price);

        uint sizeDelta = _balance * 5;

        trxKey = IPositionRouter(positionRouterGMX).createIncreasePosition{
            value: 100000000000000
        }(
            path,
            tokenAddressWETH,
            _balance,
            0,
            sizeDelta,
            true,
            _price,
            100000000000000,
            reveralCode,
            address(0)
        );
    }

    /* ====== Internal Functions ====== */

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(routerGMX).approvePlugin(positionRouterGMX);
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer(uint _balance) internal {
        require(IERC20(tokenAddressUSDC).approve(positionRouterGMX, _balance));
    }

    /* ====== Pure / View Functions ====== */

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTrxKey() public view returns (bytes32) {
        return trxKey;
    }
}
