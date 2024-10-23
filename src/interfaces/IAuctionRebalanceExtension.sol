// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAuctionRebalanceExtension {
    struct AuctionExecutionParams {
        uint256 targetUnit;
        string priceAdapterName;
        bytes priceAdapterConfigData;
    }

    function startRebalance(
        address _quoteAsset,
        address[] memory _oldComponents,
        address[] memory _newComponents,
        AuctionExecutionParams[] memory _newComponentsAuctionParams,
        AuctionExecutionParams[] memory _oldComponentsAuctionParams,
        bool _shouldLockSetToken,
        uint256 _rebalanceDuration,
        uint256 _initialPositionMultiplier
    ) external;

    function setBidderStatus(
        address[] memory _bidders,
        bool[] memory _statuses
    )
        external;
}
