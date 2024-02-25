// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ISetToken} from "../src/interfaces/ISetToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtIssuanceModuleV2} from "../src/interfaces/IDebtIssuanceModuleV2.sol";
import {AuctionBot} from "../src/AuctionBot.sol";
import {IZeroEx} from "../src/interfaces/IZeroEx.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import "../src/interfaces/uniswap/IUniV3Quoter.sol";
import "../src/interfaces/IExchangeIssuanceZeroEx.sol";
import "../src/interfaces/IExchangeIssuanceLeveraged.sol";
import "../src/interfaces/uniswap/IUniV3SwapRouter.sol";
import "../src/interfaces/uniswap/IUniswapV3Pool.sol";
import "../src/interfaces/IOptimisticAuctionRebalanceExtensionV1.sol";
import "../src/interfaces/IAuctionRebalanceModule.sol";

contract TestAuctionBot is Test {
    uint256 optimisticAuctionBlock = 18991228;

    // Uniswap V3 pools
    IUniswapV3Pool rethPool = IUniswapV3Pool(0x553e9C493678d8606d6a5ba284643dB2110Df823);
    IUniswapV3Pool wstEthPool = IUniswapV3Pool(0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa);
    IUniswapV3Pool sfrxEthPool = IUniswapV3Pool(0xeed4603BC333EF406E5EB691BA66798d5c857d8B);
    IUniswapV3Pool swEthPool = IUniswapV3Pool(0x30eA22C879628514f1494d4BBFEF79D21A6B49A2);
    IUniswapV3Pool ethXPool = IUniswapV3Pool(0x1b9669b12959Ad51B01FaBcF01EaBDFADB82f578);
    IUniswapV3Pool osEthUsdcPool = IUniswapV3Pool(0xC2A6798447BB70E5abCf1b0D6aeeC90BC14FCA55);

    // BalancerPoolId for OsEth trade
    bytes32 osEthBalancerPoolId = 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635;
    // Token Whales to obtain tokens from for testing
    address rethWhaleAddress = 0x714301eB35fE043FAa547976ce15BcE57BD53144;
    address arbBotOwner = 0xDeA58CC4a6B82CaADaF1abEf2af10fEf7E8bfCCB;


    address auctionRebalanceModuleAddress = 0x59D55D53a715b3B4581c52098BCb4075C2941DBa;

    address dsEthAddress = 0x341c05c0E9b33C0E38d64de76516b2Ce970bB3BE;
    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Components
    address rEthAddress = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address wstEthAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address sfrxEthAddress = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address swEthAddress = 0xf951E335afb289353dc249e82926178EaC7DEd78;
    // TODO: Find alternative arb strategy: Apparently there is no osEth liquidity on uniswap. Probably have to trade on balancer
    address osEthAddress = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
    address ethXAddress = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

    address uniRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address aaveV2Pool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IAuctionRebalanceModule auctionRebalanceModule = IAuctionRebalanceModule(auctionRebalanceModuleAddress);

    ISetToken dsETH = ISetToken(dsEthAddress);
    IWETH weth = IWETH(wethAddress);
    IERC20 rEth = IERC20(rEthAddress);
    IERC20 wstEth = IERC20(wstEthAddress);
    IUniV3Quoter private constant uniV3Quoter = IUniV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    AuctionBot auctionBot = AuctionBot(0xB3001800982d59c19e71027bBaA9Cf1D301aaf1d);


    function testOptimisticAuctionReth() public {
        vm.createSelectFork("mainnet", optimisticAuctionBlock);
        _startRebalance();

        uint64 secondsToForward = 60 * 60 * 4;
        uint256 componentQuantityPercentage = 100;
        console.log("Forwarding time to: ", block.timestamp + secondsToForward);

        vm.warp(block.timestamp + secondsToForward);
        _fulfillComponentBid(rEthAddress, componentQuantityPercentage, rethPool);
    }

    function testOptimisticAuctionWstEth() public {
        vm.createSelectFork("mainnet", optimisticAuctionBlock);
        _startRebalance();

        uint64 secondsToForward = 60 * 60 * 4;
        uint256 componentQuantityPercentage = 100;
        console.log("Forwarding time to: ", block.timestamp + secondsToForward);
        vm.warp(block.timestamp + secondsToForward);
        _fulfillComponentBid(wstEthAddress, componentQuantityPercentage, wstEthPool);
    }

    function testOptimisticAuctionSfrxEth() public {
        vm.createSelectFork("mainnet", optimisticAuctionBlock);
        _startRebalance();

        uint64 secondsToForward = 60 * 60 * 5;
        uint256 componentQuantityPercentage = 100;
        console.log("Forwarding time to: ", block.timestamp + secondsToForward);
        vm.warp(block.timestamp + secondsToForward);
        _fulfillComponentBid(sfrxEthAddress, componentQuantityPercentage, sfrxEthPool);
    }

    function testOptimisticAuctionEthX() public {
        vm.createSelectFork("mainnet", optimisticAuctionBlock);
        _startRebalance();

        uint64 secondsToForward = 60 * 340;
        uint256 componentQuantityPercentage = 100;
        console.log("Forwarding time to: ", block.timestamp + secondsToForward);
        vm.warp(block.timestamp + secondsToForward);

        // Fulfill all sell auctions so the token has enough weth to buy the new component
        _fulfillComponentBid(rEthAddress, componentQuantityPercentage, rethPool);
        _fulfillComponentBid(wstEthAddress, componentQuantityPercentage, wstEthPool);
        _fulfillComponentBid(sfrxEthAddress, componentQuantityPercentage, sfrxEthPool);

        // TODO: Check if the resulting price here would be acceptable, otherwise we need to find alternative trading venue
        _fulfillComponentBid(ethXAddress, 100, ethXPool);
    }


    function testOptimisticAuctionSwEth() public {
        vm.createSelectFork("mainnet", optimisticAuctionBlock);
        _startRebalance();

        uint64 secondsToForward = 60 * 60 * 5;
        uint256 componentQuantityPercentage = 100;
        console.log("Forwarding time to: ", block.timestamp + secondsToForward);
        vm.warp(block.timestamp + secondsToForward);

        // Fulfill all sell auctions so the token has enough weth to buy the new component
        _fulfillComponentBid(rEthAddress, componentQuantityPercentage, rethPool);
        _fulfillComponentBid(wstEthAddress, componentQuantityPercentage, wstEthPool);
        _fulfillComponentBid(sfrxEthAddress, componentQuantityPercentage, sfrxEthPool);

        _fulfillComponentBid(swEthAddress, componentQuantityPercentage, swEthPool);
    }

    function _fulfillComponentBidViaBalancer(address componentAddress, uint256 componentQuantityPercentage, IUniswapV3Pool pool, bytes32 balancerPoolId) internal  {
        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(dsEthAddress, componentAddress);

        uint256 componentQuantity = componentQuantityTotal * componentQuantityPercentage / 100;

        uint256 quoteQuantityLimit = isSellAuction ? type(uint256).max : 0;


        vm.prank(arbBotOwner);
        uint256 componentBalanceAfter = auctionBot.arbBidUniFlashLoanBalanceSwap(
            ISetToken(dsEthAddress),
            IERC20(componentAddress),
            IERC20(wethAddress),
            componentQuantity,
            quoteQuantityLimit,
            isSellAuction,
            pool,
            0,
            balancerPoolId
        );

    }

    function _fulfillComponentBid(address componentAddress, uint256 componentQuantityPercentage, IUniswapV3Pool pool) internal  {
        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(dsEthAddress, componentAddress);

        uint256 componentQuantity = componentQuantityTotal * componentQuantityPercentage / 100;

        uint256 quoteQuantityLimit = isSellAuction ? type(uint256).max : 0;

        uint256 uniswapPrice = _getUniswapPrice(pool, componentAddress);

        IAuctionRebalanceModule.BidInfo memory bidPreview = auctionRebalanceModule.getBidPreview(
            dsEthAddress,
            componentAddress,
            wethAddress,
            componentQuantity,
            quoteQuantityLimit,
            isSellAuction
        );



        vm.prank(arbBotOwner);
        uint256 componentBalanceAfter = auctionBot.arbBidUniFlashSwap(
            ISetToken(dsEthAddress),
            IERC20(componentAddress),
            IERC20(wethAddress),
            componentQuantity,
            quoteQuantityLimit,
            isSellAuction,
            pool,
            0
        );

        console.log("Profit: ", componentBalanceAfter);
    }

    function _getUniswapPrice(IUniswapV3Pool pool, address componentAddress) internal view  returns(uint256) {
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 uniswapPrice = ((1 ether * sqrtPriceX96 / (2 ** 96)) ** 2)/ 1 ether;
        bool isToken0 = pool.token0() == componentAddress;
        if (isToken0) {
            return uniswapPrice;
        } else {
            return 1 ether * 1 ether / uniswapPrice;
        }
    }

    function _startRebalance() internal {
        IOptimisticAuctionRebalanceExtensionV1 optimisticAuctionRebalanceExtension = IOptimisticAuctionRebalanceExtensionV1(0xf0D343Fd94ac44EF6b8baaE8dB3917d985c2cEc7);
        address quoteAsset = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address[] memory oldComponents = new address[](4);
        oldComponents[0] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        oldComponents[1] = 0xae78736Cd615f374D3085123A210448E74Fc6393;
        oldComponents[2] = 0xac3E018457B222d93114458476f3E3416Abbe38F;
        oldComponents[3] = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;

        address[] memory newComponents = new address[](2);
        newComponents[0] = 0xf951E335afb289353dc249e82926178EaC7DEd78;
        newComponents[1] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

        IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams[]  memory newComponentsAuctionParams = new IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams[](2);
        newComponentsAuctionParams[0] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 154081182673797412,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'0000000000000000000000000000000000000000000000000e66cadfa9713aba000000000000000000000000000000000000000000000000000110d9316ec000000000000000000000000000000000000000000000000000000000000000025800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e95e6ee7aef80000000000000000000000000000000000000000000000000000e66cadfa9713aba'
        });
        newComponentsAuctionParams[1] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 179461221560717457,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'0000000000000000000000000000000000000000000000000dfeaa3e423b683f00000000000000000000000000000000000000000000000000012309ce540000000000000000000000000000000000000000000000000000000000000000025800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e398811bec680000000000000000000000000000000000000000000000000000dfeaa3e423b683f'
        });

        IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams[]  memory oldComponentsAuctionParams = new IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams[](4);
        oldComponentsAuctionParams[0] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 147434795643016523,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'00000000000000000000000000000000000000000000000010217656f0433a870000000000000000000000000000000000000000000000000001c6bf526340000000000000000000000000000000000000000000000000000000000000000258000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000010217656f0433a870000000000000000000000000000000000000000000000000fda687210c13a87'
        });
        oldComponentsAuctionParams[1] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 222580769994788132,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'0000000000000000000000000000000000000000000000000f563378190ec7530000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000000000000000025800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000f563378190ec7530000000000000000000000000000000000000000000000000f0f2593398cc753'
        });
        oldComponentsAuctionParams[2] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 123550622119383244,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'0000000000000000000000000000000000000000000000000f01c80e16eb9e680000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000000000000000025800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000f01c80e16eb9e680000000000000000000000000000000000000000000000000ebaba2937699e68'
        });
        oldComponentsAuctionParams[3] = IOptimisticAuctionRebalanceExtensionV1.AuctionExecutionParams({
                targetUnit: 153506492816365590,
                priceAdapterName:	"BoundedStepwiseLinearPriceAdapter",
                priceAdapterConfigData:  hex'0000000000000000000000000000000000000000000000000e14da4081827f7a0000000000000000000000000000000000000000000000000001c6bf52634000000000000000000000000000000000000000000000000000000000000000025800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000e14da4081827f7a0000000000000000000000000000000000000000000000000de0b6b3a7640000'
        });

        uint256 rebalanceDuration =	86400;
        uint256 positionMultiplier = 997957208803707410;

        uint64 expiryTimestamp = 1705068840;

        vm.warp(expiryTimestamp);


        optimisticAuctionRebalanceExtension.startRebalance(
            quoteAsset,
            oldComponents,
            newComponents,
            newComponentsAuctionParams,
            oldComponentsAuctionParams,
            false,
            rebalanceDuration,
            positionMultiplier
        );
    }

}

