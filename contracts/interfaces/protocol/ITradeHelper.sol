// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ITradeHelper {
    function initialize(
        address _projectSettings,
        address _tokenAddressUSDC,
        address _indexTokenAddress
    ) external;
}
