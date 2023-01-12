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
        address colletarelToken;
        address indexToken;
        bool isLong;
    }

    uint256 constant EXECUTION_FEE = 100000000000000;
    uint256 constant PRICE_MULTIPLIER = 10 ** 30;
    uint256 constant MAX = type(uint256).max;
    uint8 constant MIN_TIME_DELAY = 180;

    /* ====== State Variables ====== */

    address private tokenAddressUSDC; //USDC Token only have 6 Decimals!!!
    address private tokenAddressWETH;

    address private vaultGMX;
    address private positionRouterGMX;
    address private routerGMX;

    bytes32 private trxKey;

    bool private pluginApproved;

    Position[] private positions;

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

    function openPosition(uint256 _amoutIn, uint256 _sizeDelta) public {
        // 1. approvePlugin router

        _approveRouterPlugin();

        // 2. approve router contract with the colletarel token

        _approveRouterForTokenTransfer();

        // 3. createIncreasePosition with positionRouter

        uint256 _price = IVault(vaultGMX).getMaxPrice(tokenAddressWETH);

        address[] memory path = new address[](2);

        bytes32 reveralCode;

        path[0] = tokenAddressUSDC;
        path[1] = tokenAddressWETH;

        console.log(_price);

        trxKey = IPositionRouter(positionRouterGMX).createIncreasePosition{
            value: EXECUTION_FEE
        }(
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

        positions.push(Position(tokenAddressWETH, tokenAddressWETH, true));
    }

    function executePosition(bytes32 key) public {
        IPositionRouter(positionRouterGMX).executeIncreasePosition(
            key,
            payable(address(this))
        );
    }

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

    /* ====== Pure / View Functions ====== */

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTrxKey() public view returns (bytes32) {
        return trxKey;
    }

    function getTokenDecimals(address _token) public view returns (uint256) {
        return IERC20Metadata(_token).decimals();
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
                positions[_id].colletarelToken,
                positions[_id].indexToken,
                positions[_id].isLong
            );
    }
}
