// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IStreamingFeeModule {
    struct FeeState {
        address feeRecipient;
        uint256 maxStreamingFeePercentage;
        uint256 streamingFeePercentage;
        uint256 lastStreamingFeeTimestamp;
    }

    function feeStates(address _setToken) external view returns (FeeState memory);
    function getFee(address _setToken) external view returns (uint256);
}
