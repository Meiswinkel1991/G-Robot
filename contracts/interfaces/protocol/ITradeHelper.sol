// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ITradeHelper {
    function initialize(
        address _projectSettings,
        address _tokenAddressUSDC,
        address _indexTokenAddress,
        bytes32 _referralCode
    ) external;

    function swapToIndexToken(uint256 _amountIn) external;

    function createLongPosition(uint8 _leverage, uint256 _limit) external;

    function getStableToken() external view returns (address);

    function getIndexToken() external view returns (address);
}
