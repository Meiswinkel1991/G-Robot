// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectSettings is Ownable {
    /*====== State Variables ======*/
    address private routerGMX;
    address private positionRouterGMX;
    address private vaultGMX;

    /*====== Events ======*/
    event GMXAddressesUpdated(
        address routerGMX,
        address positionRouterGMX,
        address vaultGMX
    );

    constructor() {}

    function initiliazeGMXAddresses(
        address _routerGMX,
        address _positionRouterGMX,
        address _vaultGMX
    ) external onlyOwner {
        routerGMX = _routerGMX;
        positionRouterGMX = _positionRouterGMX;
        vaultGMX = _vaultGMX;

        emit GMXAddressesUpdated(routerGMX, positionRouterGMX, vaultGMX);
    }

    /*====== Pure / View Functions ======*/

    function getRouterGMX() external view returns (address) {
        return routerGMX;
    }

    function getPositionRouterGMX() external view returns (address) {
        return positionRouterGMX;
    }

    function getVaultGMX() external view returns (address) {
        return vaultGMX;
    }
}
