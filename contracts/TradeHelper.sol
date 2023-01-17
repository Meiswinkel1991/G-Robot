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
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TradeHelper is Initializable {
    using SafeMath for uint256;

    struct PositionData {
        uint256 amount;
        uint256 entryPrice;
        uint256 size;
        uint256 exitPrice;
    }

    struct PositionRequest {
        bytes32 requestKey;
        uint256 entryPrice;
        uint256 amount;
        uint256 size;
        bool executed;
        bool increase;
    }

    /*====== GMX Addresses ======*/

    address private stableTokenAddress;
    address private indexTokenAddress;

    /*====== State Variables ======*/

    IProjectSettings private projectSettings;

    bytes32 private referralCode;

    bool private pluginApproved;

    PositionRequest private longPositionRequest;
    PositionRequest private shortPositionRequest;

    PositionData[] private longPositions;
    PositionData[] private shortPositions;

    /*====== Events ======*/

    event RequestLongPosition(
        bytes32 requestKey,
        uint256 amountIn,
        uint8 leverage
    );

    event PositionRequested(bytes32 positionKey, bool isExecuted);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _projectSettings,
        address _tokenAddressUSDC,
        address _indexTokenAddress,
        bytes32 _referralCode
    ) public initializer {
        projectSettings = IProjectSettings(_projectSettings);
        stableTokenAddress = _tokenAddressUSDC;
        indexTokenAddress = _indexTokenAddress;
        referralCode = _referralCode;
    }

    receive() external payable {}

    fallback() external payable {}

    /*====== Main Functions ======*/

    function swapToIndexToken(uint256 _amountIn) public {
        // 1. approve Router Contract
        _approveRouterForTokenTransfer(_amountIn, stableTokenAddress);

        // 2. call the swap function from router
        IRouter _router = IRouter(projectSettings.getRouterGMX());

        //Swap Function: minPrice(in) / maxPrice(out) * amountIn - Fees

        address[] memory _path = new address[](2);

        _path[0] = stableTokenAddress;
        _path[1] = indexTokenAddress;

        _router.swap(_path, _amountIn, 0, address(this));
    }

    function createLongPosition(uint8 _leverage) public {
        // 1. approvePlugin
        _approveRouterPlugin();

        // 2. approve Contract for the token
        uint256 _amountAvailable = IERC20(indexTokenAddress).balanceOf(
            address(this)
        );
        _approveRouterForTokenTransfer(_amountAvailable, indexTokenAddress);

        // 3. request the position
        address[] memory _path = new address[](1);

        _path[0] = indexTokenAddress;

        IPositionRouter _router = IPositionRouter(
            projectSettings.getPositionRouterGMX()
        );
        console.log(_amountAvailable);
        uint256 _price = IVault(projectSettings.getVaultGMX()).getMaxPrice(
            indexTokenAddress
        );
        console.log(_price);
        uint256 _sizeDelta = _price
            .mul(_leverage)
            .div(10 ** IERC20Metadata(indexTokenAddress).decimals())
            .mul(_amountAvailable);

        console.log(_sizeDelta);

        uint256 _executionFee = _router.minExecutionFee();

        bytes32 _requestKey = _router.createIncreasePosition{
            value: _executionFee
        }(
            _path,
            indexTokenAddress,
            _amountAvailable,
            0,
            _sizeDelta,
            true,
            _price,
            _executionFee,
            referralCode,
            address(this)
        );

        longPositionRequest = PositionRequest(
            _requestKey,
            _price,
            _amountAvailable,
            _sizeDelta,
            false,
            true
        );

        emit RequestLongPosition(_requestKey, _amountAvailable, _leverage);
    }

    function executePosition(bool _isLong) public {
        bool isExecuted = _isLong
            ? longPositionRequest.executed
            : shortPositionRequest.executed;

        require(!isExecuted, "Last Request already executed");

        bytes32 _key = getLastRequest(_isLong).requestKey;

        bool _increase = _isLong
            ? longPositionRequest.increase
            : shortPositionRequest.increase;

        if (_increase) {
            IPositionRouter(projectSettings.getPositionRouterGMX())
                .executeIncreasePosition(_key, payable(address(this)));
        } else {
            IPositionRouter(projectSettings.getPositionRouterGMX())
                .executeDecreasePosition(_key, payable(address(this)));
        }
    }

    function gmxPositionCallback(
        bytes32 positionKey,
        bool isExecuted,
        bool /* */
    ) public {
        if (getLastRequest(true).requestKey == positionKey) {
            longPositionRequest.executed = isExecuted;
        } else {
            shortPositionRequest.executed = isExecuted;
        }
    }

    /*====== Internal Functions ======*/

    function _approveRouterPlugin() internal {
        if (!pluginApproved) {
            IRouter(IProjectSettings(projectSettings).getRouterGMX())
                .approvePlugin(
                    IProjectSettings(projectSettings).getPositionRouterGMX()
                );
        }

        pluginApproved = true;
    }

    function _approveRouterForTokenTransfer(
        uint256 _tokenAmount,
        address _token
    ) internal {
        uint256 _allowance = IERC20(_token).allowance(
            address(this),
            projectSettings.getRouterGMX()
        );

        if (_allowance < _tokenAmount) {
            require(
                IERC20(_token).approve(
                    projectSettings.getRouterGMX(),
                    _tokenAmount
                )
            );
        }
    }

    /*====== Pure / View Functions ======*/

    function getLastRequest(
        bool _isLong
    ) public view returns (PositionRequest memory) {
        return _isLong ? longPositionRequest : shortPositionRequest;
    }

    function getStableToken() external view returns (address) {
        return stableTokenAddress;
    }

    function getIndexToken() external view returns (address) {
        return indexTokenAddress;
    }
}
