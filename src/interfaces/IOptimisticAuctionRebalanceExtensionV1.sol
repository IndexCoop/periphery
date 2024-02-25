// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IOptimisticAuctionRebalanceExtensionV1 {
    struct AuctionExecutionParams {
        uint256 targetUnit;
        string priceAdapterName;
        bytes priceAdapterConfigData;
    }

    struct AuctionExtensionParams {
        address baseManager;
        address auctionModule;
        bool useAssetAllowlist;
        address[] allowedAssets;
    }

    struct OptimisticRebalanceParams {
        address collateral;
        uint64 liveness;
        uint256 bondAmount;
        bytes32 identifier;
        address optimisticOracleV3;
    }

    event AllowedAssetAdded(address indexed _asset);
    event AllowedAssetRemoved(address indexed _asset);
    event AnyoneCallableUpdated(bool indexed _status);
    event AssertedClaim(
        address indexed setToken, address indexed _assertedBy, string rules, bytes32 _assertionId, bytes _claimData
    );
    event CallerStatusUpdated(address indexed _caller, bool _status);
    event IsOpenUpdated(bool indexed isOpen);
    event ProductSettingsUpdated(
        address indexed setToken, address indexed manager, OptimisticRebalanceParams optimisticParams, string rules
    );
    event ProposalDeleted(bytes32 assertionID, bytes32 indexed proposalHash);
    event RebalanceProposed(
        address indexed setToken,
        address indexed quoteAsset,
        address[] oldComponents,
        address[] newComponents,
        AuctionExecutionParams[] newComponentsAuctionParams,
        AuctionExecutionParams[] oldComponentsAuctionParams,
        uint256 rebalanceDuration,
        uint256 positionMultiplier
    );
    event UseAssetAllowlistUpdated(bool _status);

    function PROPOSAL_HASH_KEY() external view returns (bytes memory);
    function RULES_KEY() external view returns (bytes memory);
    function addAllowedAssets(address[] memory _assets) external;
    function anyoneCallable() external view returns (bool);
    function assertionDisputedCallback(bytes32 _assertionId) external;
    function assertionIdToProposalHash(bytes32) external view returns (bytes32);
    function assertionIds(bytes32) external view returns (bytes32);
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external;
    function assetAllowlist(address) external view returns (bool);
    function auctionModule() external view returns (address);
    function callAllowList(address) external view returns (bool);
    function getAllowedAssets() external view returns (address[] memory);
    function initialize() external;
    function isOpen() external view returns (bool);
    function manager() external view returns (address);
    function productSettings()
        external
        view
        returns (OptimisticRebalanceParams memory optimisticParams, string memory rules);
    function proposeRebalance(
        address _quoteAsset,
        address[] memory _oldComponents,
        address[] memory _newComponents,
        AuctionExecutionParams[] memory _newComponentsAuctionParams,
        AuctionExecutionParams[] memory _oldComponentsAuctionParams,
        uint256 _rebalanceDuration,
        uint256 _positionMultiplier
    ) external;
    function removeAllowedAssets(address[] memory _assets) external;
    function setAnyoneBid(bool _status) external;
    function setBidderStatus(address[] memory _bidders, bool[] memory _statuses) external;
    function setProductSettings(OptimisticRebalanceParams memory _optimisticParams, string memory _rules) external;
    function setRaiseTargetPercentage(uint256 _raiseTargetPercentage) external;
    function setToken() external view returns (address);
    function startRebalance(
        address _quoteAsset,
        address[] memory _oldComponents,
        address[] memory _newComponents,
        AuctionExecutionParams[] memory _newComponentsAuctionParams,
        AuctionExecutionParams[] memory _oldComponentsAuctionParams,
        bool _shouldLockSetToken,
        uint256 _rebalanceDuration,
        uint256 _positionMultiplier
    ) external;
    function unlock() external;
    function updateAnyoneCallable(bool _status) external;
    function updateCallerStatus(address[] memory _callers, bool[] memory _statuses) external;
    function updateIsOpen(bool _isOpen) external;
    function updateUseAssetAllowlist(bool _useAssetAllowlist) external;
    function useAssetAllowlist() external view returns (bool);
}
