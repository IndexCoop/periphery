// SPDX-License-Identifer: UNLICENSED
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external;
}
