// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IProjectSettings {
    function initiliazeGMXAddresses(
        address _routerGMX,
        address _positionRouterGMX,
        address _vaultGMX
    ) external;

    function getRouterGMX() external view returns (address);

    function getPositionRouterGMX() external view returns (address);

    function getVaultGMX() external view returns (address);
}
