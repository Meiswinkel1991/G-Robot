// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ITradeHelper {
    function initialize(
        address _projectSettings,
        address _tokenAddressUSDC,
        address _indexTokenAddress,
        bytes32 _referralCode
    ) external;

    function createDecreasePositionRequest(
        bool _isLong,
        uint256 _amountOut,
        uint256 _deltaSize
    ) external;

    function getStableToken() external view returns (address);

    function getIndexToken() external view returns (address);
}
