// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IBotManager {
    function updatePosition(
        uint256 _limitTrigger,
        uint256 _size,
        uint256 _col,
        uint256 _price,
        bool _isLong
    ) external;
}
