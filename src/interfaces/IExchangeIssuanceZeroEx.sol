pragma solidity ^0.8.13;

interface IExchangeIssuanceZeroEx {
    event ExchangeIssue(
        address indexed _recipient,
        address indexed _setToken,
        address indexed _inputToken,
        uint256 _amountInputToken,
        uint256 _amountSetIssued
    );
    event ExchangeRedeem(
        address indexed _recipient,
        address indexed _setToken,
        address indexed _outputToken,
        uint256 _amountSetRedeemed,
        uint256 _amountOutputToken
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function ETH_ADDRESS() external view returns (address);
    function WETH() external view returns (address);
    function approveSetToken(address _setToken, address _issuanceModule) external;
    function approveToken(address _token, address _spender) external;
    function approveTokens(address[] memory _tokens, address _spender) external;
    function getRequiredIssuanceComponents(
        address _issuanceModule,
        bool _isDebtIssuance,
        address _setToken,
        uint256 _amountSetToken
    ) external view returns (address[] memory components, uint256[] memory positions);
    function getRequiredRedemptionComponents(
        address _issuanceModule,
        bool _isDebtIssuance,
        address _setToken,
        uint256 _amountSetToken
    ) external view returns (address[] memory components, uint256[] memory positions);
    function issueExactSetFromETH(
        address _setToken,
        uint256 _amountSetToken,
        bytes[] memory _componentQuotes,
        address _issuanceModule,
        bool _isDebtIssuance
    ) external payable returns (uint256);
    function issueExactSetFromToken(
        address _setToken,
        address _inputToken,
        uint256 _amountSetToken,
        uint256 _maxAmountInputToken,
        bytes[] memory _componentQuotes,
        address _issuanceModule,
        bool _isDebtIssuance
    ) external returns (uint256);
    function owner() external view returns (address);
    function redeemExactSetForETH(
        address _setToken,
        uint256 _amountSetToken,
        uint256 _minEthReceive,
        bytes[] memory _componentQuotes,
        address _issuanceModule,
        bool _isDebtIssuance
    ) external returns (uint256);
    function redeemExactSetForToken(
        address _setToken,
        address _outputToken,
        uint256 _amountSetToken,
        uint256 _minOutputReceive,
        bytes[] memory _componentQuotes,
        address _issuanceModule,
        bool _isDebtIssuance
    ) external returns (uint256);
    function renounceOwnership() external;
    function setController() external view returns (address);
    function swapTarget() external view returns (address);
    function transferOwnership(address newOwner) external;
    function withdrawTokens(address[] memory _tokens, address _to) external payable;
}
