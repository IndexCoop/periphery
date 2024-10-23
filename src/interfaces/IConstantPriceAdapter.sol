// SPDX-License-Identifer: UNLICENSED
pragma solidity ^0.8.0;

interface IConstantPriceAdapter {
    function getEncodedData(uint256 _price) external view returns (bytes memory);
}
