// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IOptimisticOracleV3 {
    struct Assertion {
        EscalationManagerSettings escalationManagerSettings;
        address asserter;
        uint64 assertionTime;
        bool settled;
        address currency;
        uint64 expirationTime;
        bool settlementResolution;
        bytes32 domainId;
        bytes32 identifier;
        uint256 bond;
        address callbackRecipient;
        address disputer;
    }

    struct EscalationManagerSettings {
        bool arbitrateViaEscalationManager;
        bool discardOracle;
        bool validateDisputers;
        address assertingCaller;
        address escalationManager;
    }

    event AdminPropertiesSet(address defaultCurrency, uint64 defaultLiveness, uint256 burnedBondPercentage);
    event AssertionDisputed(bytes32 indexed assertionId, address indexed caller, address indexed disputer);
    event AssertionMade(
        bytes32 indexed assertionId,
        bytes32 domainId,
        bytes claim,
        address indexed asserter,
        address callbackRecipient,
        address escalationManager,
        address caller,
        uint64 expirationTime,
        address currency,
        uint256 bond,
        bytes32 indexed identifier
    );
    event AssertionSettled(
        bytes32 indexed assertionId,
        address indexed bondRecipient,
        bool disputed,
        bool settlementResolution,
        address settleCaller
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function assertTruth(
        bytes memory claim,
        address asserter,
        address callbackRecipient,
        address escalationManager,
        uint64 liveness,
        address currency,
        uint256 bond,
        bytes32 identifier,
        bytes32 domainId
    ) external returns (bytes32 assertionId);
    function assertTruthWithDefaults(bytes memory claim, address asserter) external returns (bytes32);
    function assertions(bytes32)
        external
        view
        returns (
            EscalationManagerSettings memory escalationManagerSettings,
            address asserter,
            uint64 assertionTime,
            bool settled,
            address currency,
            uint64 expirationTime,
            bool settlementResolution,
            bytes32 domainId,
            bytes32 identifier,
            uint256 bond,
            address callbackRecipient,
            address disputer
        );
    function burnedBondPercentage() external view returns (uint256);
    function cachedCurrencies(address) external view returns (bool isWhitelisted, uint256 finalFee);
    function cachedIdentifiers(bytes32) external view returns (bool);
    function cachedOracle() external view returns (address);
    function defaultCurrency() external view returns (address);
    function defaultIdentifier() external view returns (bytes32);
    function defaultLiveness() external view returns (uint64);
    function disputeAssertion(bytes32 assertionId, address disputer) external;
    function finder() external view returns (address);
    function getAssertion(bytes32 assertionId) external view returns (Assertion memory);
    function getAssertionResult(bytes32 assertionId) external view returns (bool);
    function getCurrentTime() external view returns (uint256);
    function getMinimumBond(address currency) external view returns (uint256);
    function multicall(bytes[] memory data) external returns (bytes[] memory results);
    function numericalTrue() external view returns (int256);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function setAdminProperties(address _defaultCurrency, uint64 _defaultLiveness, uint256 _burnedBondPercentage)
        external;
    function settleAndGetAssertionResult(bytes32 assertionId) external returns (bool);
    function settleAssertion(bytes32 assertionId) external;
    function stampAssertion(bytes32 assertionId) external view returns (bytes memory);
    function syncUmaParams(bytes32 identifier, address currency) external;
    function transferOwnership(address newOwner) external;
}
