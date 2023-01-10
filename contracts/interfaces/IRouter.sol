// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IRouter {
    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external;
}
