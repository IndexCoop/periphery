// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAuctionRebalanceModule {
    struct AuctionExecutionParams {
        uint256 targetUnit;
        string priceAdapterName;
        bytes priceAdapterConfigData;
    }

    struct BidInfo {
        address setToken;
        address sendToken;
        address receiveToken;
        address priceAdapter;
        bytes priceAdapterConfigData;
        bool isSellAuction;
        uint256 auctionQuantity;
        uint256 componentPrice;
        uint256 quantitySentBySet;
        uint256 quantityReceivedBySet;
        uint256 preBidTokenSentBalance;
        uint256 preBidTokenReceivedBalance;
        uint256 setTotalSupply;
    }

    event AnyoneBidUpdated(address indexed setToken, bool isAnyoneAllowedToBid);
    event AssetTargetsRaised(address indexed setToken, uint256 newPositionMultiplier);
    event BidExecuted(
        address indexed setToken,
        address indexed sendToken,
        address indexed receiveToken,
        address bidder,
        address priceAdapter,
        bool isSellAuction,
        uint256 price,
        uint256 netQuantitySentBySet,
        uint256 netQuantityReceivedBySet,
        uint256 protocolFee,
        uint256 setTotalSupply
    );
    event BidderStatusUpdated(address indexed setToken, address indexed bidder, bool isBidderAllowed);
    event LockedRebalanceEndedEarly(address indexed setToken);
    event RaiseTargetPercentageUpdated(address indexed setToken, uint256 newRaiseTargetPercentage);
    event RebalanceStarted(
        address indexed setToken,
        address indexed quoteAsset,
        bool isSetTokenLocked,
        uint256 rebalanceDuration,
        uint256 initialPositionMultiplier,
        address[] componentsInvolved,
        AuctionExecutionParams[] auctionParameters
    );

    function allTargetsMet(address _setToken) external view returns (bool);
    function bid(
        address _setToken,
        address _component,
        address _quoteAsset,
        uint256 _componentAmount,
        uint256 _quoteAssetLimit,
        bool _isSellAuction
    ) external;
    function canRaiseAssetTargets(address _setToken) external view returns (bool);
    function canUnlockEarly(address _setToken) external view returns (bool);
    function controller() external view returns (address);
    function executionInfo(address, address)
        external
        view
        returns (uint256 targetUnit, string memory priceAdapterName, bytes memory priceAdapterConfigData);
    function getAllowedBidders(address _setToken) external view returns (address[] memory);
    function getAuctionSizeAndDirection(address _setToken, address _component)
        external
        view
        returns (bool isSellAuction, uint256 componentQuantity);
    function getBidPreview(
        address _setToken,
        address _component,
        address _quoteAsset,
        uint256 _componentQuantity,
        uint256 _quoteQuantityLimit,
        bool _isSellAuction
    ) external view returns (BidInfo memory);
    function getQuoteAssetBalance(address _setToken) external view returns (uint256);
    function getRebalanceComponents(address _setToken) external view returns (address[] memory);
    function initialize(address _setToken) external;
    function isAllowedBidder(address _setToken, address _bidder) external view returns (bool);
    function isQuoteAssetExcessOrAtTarget(address _setToken) external view returns (bool);
    function isRebalanceDurationElapsed(address _setToken) external view returns (bool);
    function permissionInfo(address) external view returns (bool isAnyoneAllowedToBid);
    function raiseAssetTargets(address _setToken) external;
    function rebalanceInfo(address)
        external
        view
        returns (
            address quoteAsset,
            uint256 rebalanceStartTime,
            uint256 rebalanceDuration,
            uint256 positionMultiplier,
            uint256 raiseTargetPercentage
        );
    function removeModule() external;
    function setAnyoneBid(address _setToken, bool _status) external;
    function setBidderStatus(address _setToken, address[] memory _bidders, bool[] memory _statuses) external;
    function setRaiseTargetPercentage(address _setToken, uint256 _raiseTargetPercentage) external;
    function startRebalance(
        address _setToken,
        address _quoteAsset,
        address[] memory _newComponents,
        AuctionExecutionParams[] memory _newComponentsAuctionParams,
        AuctionExecutionParams[] memory _oldComponentsAuctionParams,
        bool _shouldLockSetToken,
        uint256 _rebalanceDuration,
        uint256 _initialPositionMultiplier
    ) external;
    function unlock(address _setToken) external;
}
