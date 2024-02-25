// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental "ABIEncoderV2";

interface IDebtIssuanceModuleV2 {
    event FeeRecipientUpdated(address indexed _setToken, address _newFeeRecipient);
    event IssueFeeUpdated(address indexed _setToken, uint256 _newIssueFee);
    event RedeemFeeUpdated(address indexed _setToken, uint256 _newRedeemFee);
    event SetTokenIssued(
        address indexed _setToken,
        address indexed _issuer,
        address indexed _to,
        address _hookContract,
        uint256 _quantity,
        uint256 _managerFee,
        uint256 _protocolFee
    );
    event SetTokenRedeemed(
        address indexed _setToken,
        address indexed _redeemer,
        address indexed _to,
        uint256 _quantity,
        uint256 _managerFee,
        uint256 _protocolFee
    );

    function calculateTotalFees(address _setToken, uint256 _quantity, bool _isIssue)
        external
        view
        returns (uint256 totalQuantity, uint256 managerFee, uint256 protocolFee);
    function controller() external view returns (address);
    function getModuleIssuanceHooks(address _setToken) external view returns (address[] memory);
    function getRequiredComponentIssuanceUnits(address _setToken, uint256 _quantity)
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory);
    function getRequiredComponentRedemptionUnits(address _setToken, uint256 _quantity)
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory);
    function initialize(
        address _setToken,
        uint256 _maxManagerFee,
        uint256 _managerIssueFee,
        uint256 _managerRedeemFee,
        address _feeRecipient,
        address _managerIssuanceHook
    ) external;
    function isModuleIssuanceHook(address _setToken, address _hook) external view returns (bool);
    function issuanceSettings(address)
        external
        view
        returns (
            uint256 maxManagerFee,
            uint256 managerIssueFee,
            uint256 managerRedeemFee,
            address feeRecipient,
            address managerIssuanceHook
        );
    function issue(address _setToken, uint256 _quantity, address _to) external;
    function redeem(address _setToken, uint256 _quantity, address _to) external;
    function registerToIssuanceModule(address _setToken) external;
    function removeModule() external;
    function unregisterFromIssuanceModule(address _setToken) external;
    function updateFeeRecipient(address _setToken, address _newFeeRecipient) external;
    function updateIssueFee(address _setToken, uint256 _newIssueFee) external;
    function updateRedeemFee(address _setToken, uint256 _newRedeemFee) external;
}
