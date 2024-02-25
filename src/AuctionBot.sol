// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAuctionRebalanceModule.sol";
import "./interfaces/uniswap/IUniswapV3Pool.sol";
import "./interfaces/balancer/IBalancerVault.sol";
import "./interfaces/ISetToken.sol";

contract AuctionBot is Ownable {
    IAuctionRebalanceModule public auctionRebalanceModule;

    // Copied from: https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/libraries/TickMath.sol#L13
    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// This is used to prevent unauthorized calls to the callback functions
    /// It should be set before handing off control to the flashloan provider and set back to 0 at the end of the callback
    address internal allowedCallback;

    IBalancerVault public constant balancerVault = IBalancerVault(payable(0xBA12222222228d8Ba445958a75a0704d566BF2C8));

    mapping(address => bool) public allowedCallers;
    bool public anyoneAllowed;

    struct Bid {
        ISetToken setToken;
        IERC20 component;
        IERC20 quoteAsset;
        uint256 componentAmount;
        uint256 quoteAssetLimit;
        bool isSellAuction;
    }

    struct BalancerData {
        bool receivingToken1; 
        uint256 amountSpecified;
        bytes32 balancerPoolId;
    }

    constructor(address _auctionRebalanceModule) {
        auctionRebalanceModule = IAuctionRebalanceModule(_auctionRebalanceModule);
        allowedCallers[msg.sender] = true;
    }

    modifier checkCallback() {
        require(msg.sender == allowedCallback, "AuctionBot: msg.sender != allowedCallback");
        _;
        allowedCallback = address(0);
    }

    modifier onlyAllowedCallers() {
        require(anyoneAllowed || allowedCallers[msg.sender], "AuctionBot: msg.sender not allowed");
        _;
    }

    // ******** ADMIN FUNCTIONS ********
    function setAllowedCaller(address _caller, bool _allowed) external onlyOwner {
        allowedCallers[_caller] = _allowed;
    }

    function setAnyoneAllowed(bool _allowed) external onlyOwner {
        anyoneAllowed = _allowed;
    }

    function withdrawToken(IERC20 _token, uint256 _amount) external onlyOwner {
        _token.transfer(msg.sender, _amount);
    }

    // ******** Arb entrypoints ********

    // This function implements the bid via flash swap. Basically getting the output tokens of the swap immediately
    // and deferring the repayment to the end of the callback. Thereby we don't need to do an additional flashloan.
    // This works only for tokens that have a sufficiently liquid Uni V3 pool with the quote asset.
    function arbBidUniFlashSwap(
        ISetToken _setToken,
        IERC20 _component,
        IERC20 _quoteAsset,
        uint256 _componentAmount,
        uint256 _quoteAssetLimit,
        bool _isSellAuction,
        IUniswapV3Pool _pool,
        uint256 _minBalanceAfter
    ) external onlyAllowedCallers returns(uint256) {
        (bool zeroForOne, uint256 swapAmount) = _calculateSwapAmountAndDirection(_setToken, _component, _quoteAsset, _componentAmount, _quoteAssetLimit, _isSellAuction, _pool);

        Bid memory bid = Bid({
            setToken: _setToken,
            component: _component,
            quoteAsset: _quoteAsset,
            componentAmount: _componentAmount,
            quoteAssetLimit: _quoteAssetLimit,
            isSellAuction: _isSellAuction
        });

        bytes memory encodedBid = abi.encode(bid);
        allowedCallback = address(_pool);
        _pool.swap(
            address(this),
            zeroForOne,
            -int256(swapAmount),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            encodedBid
        );

        IERC20 tokenOut = _isSellAuction ? _component : _quoteAsset;
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        require(balanceAfter >= _minBalanceAfter, "AuctionBot: balanceAfter < minBalanceAfter");
        return(balanceAfter);
    }

    // This function implements the bid via a combination of a Uniswap "Flashloan" (although they refer to this as Flashswap in their docs)
    // and a Balancer swap between component and quote asset.
    function arbBidUniFlashLoanBalanceSwap(
        ISetToken _setToken,
        IERC20 _component,
        IERC20 _quoteAsset,
        uint256 _componentAmount,
        uint256 _quoteAssetLimit,
        bool _isSellAuction,
        IUniswapV3Pool _pool,
        uint256 _minBalanceAfter,
        bytes32 _balancerPoolId
    ) external onlyAllowedCallers returns(uint256) {
        (bool receivingToken1, uint256 amountSpecified) = _calculateSwapAmountAndDirection(_setToken, _component, _quoteAsset, _componentAmount, _quoteAssetLimit, _isSellAuction, _pool);

        Bid memory bid = Bid({
            setToken: _setToken,
            component: _component,
            quoteAsset: _quoteAsset,
            componentAmount: _componentAmount,
            quoteAssetLimit: _quoteAssetLimit,
            isSellAuction: _isSellAuction
        });

        BalancerData  memory balancerData = BalancerData({
            receivingToken1: receivingToken1,
            amountSpecified: amountSpecified,
            balancerPoolId: _balancerPoolId
        });

        bytes memory encodedBid = abi.encode(bid, balancerData);

        _callUniswapPoolFlashLoan(_pool, receivingToken1, amountSpecified, encodedBid);

        IERC20 tokenOut = _isSellAuction ? _component : _quoteAsset;
        uint256 balanceAfter = tokenOut.balanceOf(address(this));
        require(balanceAfter >= _minBalanceAfter, "AuctionBot: balanceAfter < minBalanceAfter");
        return(balanceAfter);
    }

    // ******** Callbacks ********

    // @dev Called by UniswapV3Pool after a swap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external checkCallback {
        Bid memory bid = abi.decode(data, (Bid));
        uint256  amountToRepay = amount1Delta > 0 ? uint256(amount1Delta) : uint256(amount0Delta);
        if(bid.isSellAuction) {
            _executeSellBid(amountToRepay, bid);
            bid.component.transfer(msg.sender, amountToRepay);
        } else {
            _executeBuyBid(amountToRepay, bid);
            bid.quoteAsset.transfer(msg.sender, amountToRepay);
        }
    }

    // @dev Called by UniswapV3Pool after a flashloan
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external checkCallback {
        (Bid memory bid, BalancerData memory balancerData) = abi.decode(data, (Bid, BalancerData));
        uint256 amountToRepay = balancerData.receivingToken1 ? balancerData.amountSpecified + fee1 : balancerData.amountSpecified + fee0;
        uint256 componentBalance  = bid.component.balanceOf(address(this));
        if(bid.isSellAuction) {
            _executeSellBid(amountToRepay, bid);
            _fixedOutputSellBalancer(bid.component, bid.quoteAsset, amountToRepay, balancerData.balancerPoolId);
            bid.quoteAsset.transfer(msg.sender, amountToRepay);
        } else {
            _executeBuyBid(amountToRepay, bid);
            _fixedOutputSellBalancer(bid.quoteAsset, bid.component, amountToRepay, balancerData.balancerPoolId);
            bid.component.transfer(msg.sender, amountToRepay);
        }
    }

    // ******** Internal functions ********

    // @dev Initiates Uniswap Flashloan
    function _callUniswapPoolFlashLoan(
        IUniswapV3Pool _pool,
        bool _receivingToken1,
        uint256 _amountSpecified,
        bytes memory _encodedBid
    ) internal {
        uint256 amount0 = _receivingToken1 ? 0 : _amountSpecified;
        uint256 amount1 = _receivingToken1 ? _amountSpecified : 0;

        allowedCallback = address(_pool);
        _pool.flash(
            address(this),
            amount0,
            amount1,
            _encodedBid
        );
    }

    // @dev Calculate the amount (fixed output) to swap for and direction in terms of token0/1 on the pool
    function _calculateSwapAmountAndDirection(
        ISetToken _setToken,
        IERC20 _component,
        IERC20 _quoteAsset,
        uint256 _componentAmount,
        uint256 _quoteAssetLimit,
        bool _isSellAuction,
        IUniswapV3Pool _pool
    ) internal view returns (bool, uint256) {
        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(address(_setToken), address(_component), address(_quoteAsset), _componentAmount, _quoteAssetLimit, _isSellAuction);
        bool zeroForOne = bidInfo.receiveToken == _pool.token1();
        
        return (zeroForOne, bidInfo.quantityReceivedBySet);
    }

    // @dev Execute a sell bid on the auction module paying in quoteAsset and getting component
    function _executeSellBid(uint256 amountToRepay, Bid memory bid) internal {
        bid.quoteAsset.approve(address(auctionRebalanceModule), type(uint256).max);
        auctionRebalanceModule.bid(address(bid.setToken), address(bid.component), address(bid.quoteAsset), bid.componentAmount, bid.quoteAssetLimit, bid.isSellAuction);
    }

    // @dev Execute buy bid on auction module paying in component and getting quoteAsset
    function _executeBuyBid(uint256 amountToRepay, Bid memory bid) internal {
        bid.component.approve(address(auctionRebalanceModule), type(uint256).max);
        auctionRebalanceModule.bid(address(bid.setToken), address(bid.component), address(bid.quoteAsset), bid.componentAmount, bid.quoteAssetLimit, bid.isSellAuction);
    }

    // @dev Do a fixed output swap on balancer
    function _fixedOutputSellBalancer(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut, bytes32 balancerPoolId) internal {
        IBalancerVault.FundManagement  memory fundManagement = IBalancerVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        IBalancerVault.SingleSwap memory singleSwap = IBalancerVault.SingleSwap({
            poolId: balancerPoolId,
            kind: IBalancerVault.SwapKind.GIVEN_OUT,
            assetIn: address(tokenIn),
            assetOut: address(tokenOut),
            amount: amountOut,
            userData: bytes("")
        });

        tokenIn.approve(address(balancerVault), type(uint256).max);

        balancerVault.swap(singleSwap, fundManagement,  type(uint256).max, type(uint256).max);
    }
}

