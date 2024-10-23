// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ISetToken} from "../src/interfaces/ISetToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import "../src/interfaces/IAuctionRebalanceExtension.sol";
import "../src/interfaces/IAuctionRebalanceModule.sol";
import "../src/interfaces/IConstantPriceAdapter.sol";

contract TestRebalance is Test {
    uint256 rebalanceBlock = 21028842;

    address operator = 0x6904110f17feD2162a11B5FA66B188d801443Ea4;

    address twentyOneBtcAddress = 0x3f67093dfFD4F0aF4f2918703C92B60ACB7AD78b;
    address twentyOneBnbAddress = 0x1bE9d03BfC211D83CFf3ABDb94A75F9Db46e1334;
    address twentyOneXrpAddress = 0x0d3bd40758dF4F79aaD316707FcB809CD4815Ffe;
    address twentyOneAdaAddress = 0x9c05d54645306d4C4EAd6f75846000E1554c0360;
    address twentyOneSolAddress = 0xb80a1d87654BEf7aD8eB6BBDa3d2309E31D4e598;
    address twentyOneDotAddress = 0xF4ACCD20bFED4dFFe06d4C85A7f9924b1d5dA819;
    address twentyOneAvaxAddress = 0x399508A43d7E2b4451cd344633108b4d84b33B03;

    address constantPriceAdapterAddress = 0x13c33656570092555Bf27Bdf53Ce24482B85D992;
    IConstantPriceAdapter constantPriceAdapter = IConstantPriceAdapter(constantPriceAdapterAddress);

    address auctionRebalanceModuleAddress = 0x59D55D53a715b3B4581c52098BCb4075C2941DBa;
    IAuctionRebalanceModule auctionRebalanceModule = IAuctionRebalanceModule(auctionRebalanceModuleAddress);

    address ic21Address = 0x1B5E16C5b20Fb5EE87C61fE9Afe735Cca3B21A65;
    ISetToken ic21 = ISetToken(ic21Address);

    address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH weth = IWETH(wethAddress);

    function testBtcAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneBtcAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 3e8);
        assert(componentQuantityTotal < 3.5e8);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneBtcAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 85 ether);
        assert(bidInfo.quantityReceivedBySet < 86 ether);
    }

    function testBnbAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneBnbAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 103e8);
        assert(componentQuantityTotal < 104e8);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneBnbAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 23 ether);
        assert(bidInfo.quantityReceivedBySet < 24 ether);
    }

    function testXrpAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneXrpAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 56361e6);
        assert(componentQuantityTotal < 56362e6);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneXrpAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 11 ether);
        assert(bidInfo.quantityReceivedBySet < 12 ether);
    }

    function testAdaAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneAdaAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 41183e6);
        assert(componentQuantityTotal < 41184e6);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneAdaAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 5 ether);
        assert(bidInfo.quantityReceivedBySet < 6 ether);
    }

    function testSolAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneSolAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 355e9);
        assert(componentQuantityTotal < 356e9);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneSolAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 23 ether);
        assert(bidInfo.quantityReceivedBySet < 24 ether);
    }

    function testAvaxAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneAvaxAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 546e18);
        assert(componentQuantityTotal < 547e18);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneAvaxAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 5 ether);
        assert(bidInfo.quantityReceivedBySet < 6 ether);
    }

    function testDotAuction() public {
        vm.createSelectFork("mainnet", rebalanceBlock);
        _startRebalance();

        (bool isSellAuction, uint256 componentQuantityTotal) = auctionRebalanceModule.getAuctionSizeAndDirection(ic21Address, twentyOneDotAddress);
        assert(isSellAuction);

        assert(componentQuantityTotal > 2222e10);
        assert(componentQuantityTotal < 2223e10);

        IAuctionRebalanceModule.BidInfo memory bidInfo = auctionRebalanceModule.getBidPreview(
            ic21Address,
            twentyOneDotAddress,
            wethAddress,
            componentQuantityTotal,
            type(uint256).max,
            true
        );

        assertEq(bidInfo.quantitySentBySet, componentQuantityTotal);

        assert(bidInfo.quantityReceivedBySet > 3 ether);
        assert(bidInfo.quantityReceivedBySet < 4 ether);
    }

    function _startRebalance() internal {
        IAuctionRebalanceExtension auctionRebalanceExtension = IAuctionRebalanceExtension(0x94cAEa398acC5931B1d32c548959A160Ac37Ff4a);

        address quoteAsset = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address[] memory oldComponents = new address[](8);
        oldComponents[0] = twentyOneBtcAddress;
        oldComponents[1] = wethAddress;
        oldComponents[2] = twentyOneBnbAddress;
        oldComponents[3] = twentyOneXrpAddress;
        oldComponents[4] = twentyOneAdaAddress;
        oldComponents[5] = twentyOneSolAddress;
        oldComponents[6] = twentyOneAvaxAddress;
        oldComponents[7] = twentyOneDotAddress;

        IAuctionRebalanceExtension.AuctionExecutionParams[]  memory oldComponentsAuctionParams = new IAuctionRebalanceExtension.AuctionExecutionParams[](8);
        
        // 21 BTC
        oldComponentsAuctionParams[0] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(
                    26.45 ether * 1 ether / 1e8
                )
        });

        // WETH
        oldComponentsAuctionParams[1] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 16461249555370868,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(1 ether)
        });

        // 21 BNB
        oldComponentsAuctionParams[2] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(
                    0.23 ether * 1 ether / 1e8
                )
        });

        // 21 XRP
        oldComponentsAuctionParams[3] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(
                    0.00021 ether * 1 ether / 1e6
                )
        });

        // 21 ADA
        oldComponentsAuctionParams[4] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(
                    0.00014 ether * 1 ether / 1e6
                )
        });

        // 21 SOL
        oldComponentsAuctionParams[5] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData: constantPriceAdapter.getEncodedData(
                    0.06638 ether * 1 ether / 1e9
                )
        });

        // 21 AVAX
        oldComponentsAuctionParams[6] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData:  constantPriceAdapter.getEncodedData(
                    0.01051 ether
                )
        });

        // 21 DOT
        oldComponentsAuctionParams[7] = IAuctionRebalanceExtension.AuctionExecutionParams({
                targetUnit: 0,
                priceAdapterName:	"ConstantPriceAdapter",
                priceAdapterConfigData:  constantPriceAdapter.getEncodedData(
                    0.001665 ether * 1 ether / 1e10
                )
        });

        uint256 rebalanceDuration =	7200;
        uint256 positionMultiplier = 1000000000000000000;

        uint64 expiryTimestamp = 1705068840;
        vm.warp(expiryTimestamp);

        vm.prank(operator);
        auctionRebalanceExtension.startRebalance(
            quoteAsset,
            oldComponents,
            new address[](0),
            new IAuctionRebalanceExtension.AuctionExecutionParams[](0),
            oldComponentsAuctionParams,
            false,
            rebalanceDuration,
            positionMultiplier
        );
    }
}
