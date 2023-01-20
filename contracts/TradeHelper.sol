// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "./interfaces/protocol/IProjectSettings.sol";
import "./interfaces/protocol/IBotManager.sol";

import "./interfaces/IPositionRouter.sol";

import "./interfaces/IERC20Metadata.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IRouter.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TradeHelper is Initializable {
    using SafeMath for uint256;

    struct PositionRequest {
        bytes32 requestKey;
        uint256 entryPrice;
        uint256 amount;
        uint256 size;
        uint256 limitTrigger;
        bool executed;
        bool increase;
    }

    /*====== GMX Addresses ======*/

    address private stableTokenAddress;
    address private indexTokenAddress;

    /*====== State Variables ======*/

    bytes32 private referralCode;

    // slippage in 10th percent point : e.g. 1% = 1010
    uint256 private constant slippage = 1010;

    bool private pluginApproved;

    uint256 private collateralLong;
    uint256 private collateralShort;

    uint256 private sizeLong;
    uint256 private sizeShort;

    IProjectSettings private projectSettings;
    IBotManager private botManager;

    PositionRequest private longPositionRequest;
    PositionRequest private shortPositionRequest;

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
        botManager = IBotManager(msg.sender);
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

    function createLongPosition(
        uint8 _leverage,
        uint256 _limit
    ) public payable {
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

        uint256 _price = IVault(projectSettings.getVaultGMX())
            .getMaxPrice(indexTokenAddress)
            .mul(slippage)
            .div(1000);
        console.log(_price);
        uint256 _sizeDelta = _price
            .mul(_leverage)
            .div(10 ** IERC20Metadata(indexTokenAddress).decimals())
            .mul(_amountAvailable);

        bytes32 _requestKey = _router.createIncreasePosition{
            value: getExecutionFee()
        }(
            _path,
            indexTokenAddress,
            _amountAvailable,
            0,
            _sizeDelta,
            true,
            _price,
            getExecutionFee(),
            referralCode,
            address(this)
        );

        longPositionRequest = PositionRequest(
            _requestKey,
            _price,
            _amountAvailable,
            _sizeDelta,
            _limit,
            false,
            true
        );

        emit RequestLongPosition(_requestKey, _amountAvailable, _leverage);
    }

    function exitLongPosition(
        uint256 _amountOut,
        uint256 _deltaSize,
        uint8 _slippage,
        uint256 _limit
    ) external payable {
        _approveRouterPlugin();

        IPositionRouter _router = IPositionRouter(
            projectSettings.getPositionRouterGMX()
        );

        address[] memory _path = new address[](1);

        _path[0] = indexTokenAddress;

        uint256 _price = IVault(projectSettings.getVaultGMX())
            .getMinPrice(indexTokenAddress)
            .mul(1000 - _slippage)
            .div(1000);

        bytes32 _requestKey = _router.createDecreasePosition{
            value: getExecutionFee()
        }(
            _path,
            indexTokenAddress,
            _amountOut,
            _deltaSize,
            true,
            address(this),
            _price,
            0,
            getExecutionFee(),
            false,
            address(this)
        );

        longPositionRequest = PositionRequest(
            _requestKey,
            _price,
            _amountOut,
            _deltaSize,
            _limit,
            false,
            false
        );
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
        bool isIncrease
    ) public {
        uint256 _posCollateral;
        uint256 _posSize;

        if (getLastRequest(true).requestKey == positionKey) {
            longPositionRequest.executed = isExecuted;

            (uint256 _size, uint256 _col) = _getPositionInformation(true);

            _posCollateral = isIncrease ? _col.sub(collateralLong) : 0;
            _posSize = isIncrease ? _size.sub(sizeLong) : 0;

            collateralLong = _col;
            sizeLong = _size;

            botManager.updatePosition(
                longPositionRequest.limitTrigger,
                _posSize,
                _posCollateral,
                longPositionRequest.entryPrice,
                true
            );
        } else if (getLastRequest(false).requestKey == positionKey) {
            shortPositionRequest.executed = isExecuted;

            (uint256 _size, uint256 _col) = _getPositionInformation(false);

            _posCollateral = isIncrease ? _col.sub(collateralShort) : 0;
            _posSize = isIncrease ? _size.sub(sizeShort) : 0;

            collateralShort = _col;
            sizeShort = _size;

            botManager.updatePosition(
                shortPositionRequest.limitTrigger,
                _posSize,
                _posCollateral,
                shortPositionRequest.entryPrice,
                false
            );
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

    function _getPositionInformation(
        bool _isLong
    ) internal view returns (uint256, uint256) {
        (uint256 _size, uint256 _col, , , , , , ) = IVault(
            projectSettings.getVaultGMX()
        ).getPosition(
                address(this),
                _isLong ? indexTokenAddress : stableTokenAddress,
                indexTokenAddress,
                _isLong
            );
        return (_size, _col);
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

    function getCollateral(bool _isLong) external view returns (uint256) {
        return _isLong ? collateralLong : collateralShort;
    }

    function getPositionSize(bool _isLong) external view returns (uint256) {
        return _isLong ? sizeLong : sizeShort;
    }

    function getFee(bool _isLong) external view returns (uint256) {
        (uint256 _size, , , uint256 _entryFundingFee, , , , ) = IVault(
            projectSettings.getVaultGMX()
        ).getPosition(
                address(this),
                indexTokenAddress,
                indexTokenAddress,
                _isLong
            );
        return
            IVault(projectSettings.getVaultGMX()).getFundingFee(
                indexTokenAddress,
                _size,
                _entryFundingFee
            );
    }

    function getExecutionFee() public view returns (uint256) {
        return
            IPositionRouter(projectSettings.getPositionRouterGMX())
                .minExecutionFee();
    }

    function getSlippage() public view returns (uint256) {
        return slippage;
    }
}
