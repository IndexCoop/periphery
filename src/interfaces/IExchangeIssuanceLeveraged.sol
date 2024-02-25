pragma solidity ^0.8.10;

interface IExchangeIssuanceLeveraged {
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

    struct SwapData {
        address[] path;
        uint24[] fees;
        address pool;
        uint8 exchange;
    }

    struct LeveragedTokenData {
        address collateralAToken;
        address collateralToken;
        uint256 collateralAmount;
        address debtToken;
        uint256 debtAmount;
    }

    function ADDRESSES_PROVIDER() external view returns (address);
    function LENDING_POOL() external view returns (address);
    function ROUNDING_ERROR_MARGIN() external view returns (uint256);
    function aaveLeverageModule() external view returns (address);
    function addresses()
        external
        view
        returns (
            address quickRouter,
            address sushiRouter,
            address uniV3Router,
            address uniV3Quoter,
            address curveAddressProvider,
            address curveCalculator,
            address weth
        );
    function approveSetToken(address _setToken) external;
    function approveToken(address _token) external;
    function approveTokens(address[] memory _tokens) external;
    function debtIssuanceModule() external view returns (address);
    function executeOperation(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) external returns (bool);
    function getIssueExactSet(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external returns (uint256);
    function getLeveragedTokenData(address _setToken, uint256 _setAmount, bool _isIssuance)
        external
        view
        returns (LeveragedTokenData memory);
    function getRedeemExactSet(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external returns (uint256);
    function issueExactSetFromERC20(
        address _setToken,
        uint256 _setAmount,
        address _inputToken,
        uint256 _maxAmountInputToken,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external;
    function issueExactSetFromETH(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external payable;
    function redeemExactSetForERC20(
        address _setToken,
        uint256 _setAmount,
        address _outputToken,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external;
    function redeemExactSetForETH(
        address _setToken,
        uint256 _setAmount,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external;
    function setController() external view returns (address);
}

