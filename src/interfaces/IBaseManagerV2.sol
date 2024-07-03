// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IBaseManagerV2 {
    function addExtension(address _newExtension) external;
    function isExtension(address _extension) external view returns (bool);
}
