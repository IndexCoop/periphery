// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/mocks/ERC20Mock.sol";
import "../../src/staking/SnapshotStakingPool.sol";

import "../../src/interfaces/IBaseManagerV2.sol";
import "../../src/interfaces/IDebtIssuanceModuleV2.sol";
import "../../src/interfaces/IPrtFeeSplitExtension.sol";
import "../../src/interfaces/ISetToken.sol";
import "../../src/interfaces/IStreamingFeeModule.sol";

contract HyEthSnapshotStakingPoolTest is Test {
    uint256 stakingBlock = 20227420;

    address hyEthAddress = 0xc4506022Fb8090774E8A628d5084EED61D9B99Ee;
    address prtHyEthAddress = 0x99F6539Df9840592a862ab916dDc3258a1D7a773;
    address prtFeeSplitExtensionAddress = 0x43C3EF32E52f17777789c71002ef4a887df90613;

    address hyEthManagerAddress = 0x6A7EB75C50dDdA0FFa90b6577da938A6F0e35240;
    address operatorAddress = 0x6904110f17feD2162a11B5FA66B188d801443Ea4;

    address issuanceModuleAddress = 0x04b59F9F09750C044D7CfbC177561E409085f0f3;
    address streamingFeeModuleAddress = 0x165EDF07Bb61904f47800e13F5120E64C4B9A186;

    ISetToken hyEth = ISetToken(hyEthAddress);
    IERC20 prtHyEth = IERC20(prtHyEthAddress);
    IPrtFeeSplitExtension prtFeeSplitExtension = IPrtFeeSplitExtension(prtFeeSplitExtensionAddress);
    IBaseManagerV2 hyEthManager = IBaseManagerV2(hyEthManagerAddress);
    IDebtIssuanceModuleV2 issuanceModule = IDebtIssuanceModuleV2(issuanceModuleAddress);
    IStreamingFeeModule streamingFeeModule = IStreamingFeeModule(streamingFeeModuleAddress);

    uint256 public snapshotBuffer = 1 days;
    uint256 public snapshotDelay = 30 days;

    SnapshotStakingPool public snapshotStakingPool;

    VmSafe.Wallet alice = vm.createWallet("alice");
    VmSafe.Wallet bob = vm.createWallet("bob");
    VmSafe.Wallet carol = vm.createWallet("carol");

    function setUp() public {
        vm.createSelectFork("mainnet", stakingBlock);

        vm.startPrank(operatorAddress);
        hyEthManager.addExtension(prtFeeSplitExtensionAddress);
        prtFeeSplitExtension.updateFeeRecipient(prtFeeSplitExtensionAddress);
        prtFeeSplitExtension.updateFeeRecipient(prtFeeSplitExtensionAddress);

        snapshotStakingPool = new SnapshotStakingPool(
            "High Yield ETH Index Staked PRT",
            "sPrtHyETH",
            IERC20(hyEthAddress),
            prtHyEth,
            prtFeeSplitExtensionAddress,
            snapshotBuffer,
            snapshotDelay
        );

        prtFeeSplitExtension.updatePrtStakingPool(address(snapshotStakingPool));
        prtFeeSplitExtension.updatePrtStakingPool(address(snapshotStakingPool));
        prtFeeSplitExtension.updateAnyoneAccrue(true);
        prtFeeSplitExtension.updateAnyoneAccrue(true);
    }

    function testSetup() public {
        assert(hyEthManager.isExtension(prtFeeSplitExtensionAddress));

        (,,,address feeRecipient,) = issuanceModule.issuanceSettings(hyEthAddress);
        assertEq(feeRecipient, prtFeeSplitExtensionAddress);
        assertEq(streamingFeeModule.feeStates(hyEthAddress).feeRecipient, prtFeeSplitExtensionAddress);

        assertEq(snapshotStakingPool.name(), "High Yield ETH Index Staked PRT");
        assertEq(snapshotStakingPool.symbol(), "sPrtHyETH");
        assertEq(snapshotStakingPool.decimals(), 18);
        assertEq(address(snapshotStakingPool.rewardToken()), hyEthAddress);
        assertEq(address(snapshotStakingPool.stakeToken()), prtHyEthAddress);
        assertEq(address(snapshotStakingPool.distributor()), prtFeeSplitExtensionAddress);
        assertEq(snapshotStakingPool.snapshotDelay(), snapshotDelay);

        assertEq(address(prtFeeSplitExtension.prtStakingPool()), address(snapshotStakingPool));
        assert(prtFeeSplitExtension.isAnyoneAllowedToAccrue());
    }

    function testHyEthPrtStakingSystem() public {
        _stake(alice.addr, 1 ether);
        _stake(bob.addr, 1 ether);

        vm.warp(block.timestamp + snapshotDelay + 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        assert(hyEth.balanceOf(address(snapshotStakingPool)) > 0);
        assertEq(hyEth.balanceOf(address(snapshotStakingPool)), snapshotStakingPool.rewardAt(1));

        uint256 firstSnapshotPendingRewards = snapshotStakingPool.rewardAt(1) / 2;

        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), firstSnapshotPendingRewards);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), firstSnapshotPendingRewards);

        assertEq(snapshotStakingPool.getTimeUntilNextSnapshot(), snapshotDelay);
        assert(!snapshotStakingPool.canAccrue());

        vm.expectRevert(SnapshotStakingPool.SnapshotDelayNotPassed.selector);
        vm.warp(block.timestamp + snapshotDelay - 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        vm.warp(block.timestamp + snapshotDelay + 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        assertEq(hyEth.balanceOf(address(snapshotStakingPool)), snapshotStakingPool.rewardAt(1) + snapshotStakingPool.rewardAt(2));

        uint256 secondSnapshotPendingRewards = firstSnapshotPendingRewards + snapshotStakingPool.rewardAt(2) / 2;

        vm.startPrank(bob.addr);
        snapshotStakingPool.claim();
        assertEq(hyEth.balanceOf(bob.addr), secondSnapshotPendingRewards);

        vm.startPrank(alice.addr);
        snapshotStakingPool.claim();
        assertEq(hyEth.balanceOf(alice.addr), secondSnapshotPendingRewards);

        vm.warp(block.timestamp + snapshotDelay + 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        _unstake(alice.addr, 1 ether);

        vm.warp(block.timestamp + snapshotDelay + 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        vm.warp(block.timestamp + snapshotDelay + 1);
        prtFeeSplitExtension.accrueFeesAndDistribute();

        vm.startPrank(alice.addr);
        snapshotStakingPool.claim();

        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 6);

        vm.startPrank(bob.addr);
        snapshotStakingPool.claim();

        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 6);

        assertEq(hyEth.balanceOf(alice.addr), snapshotStakingPool.getLifetimeRewards(alice.addr));
        assertEq(hyEth.balanceOf(bob.addr), snapshotStakingPool.getLifetimeRewards(bob.addr));
    }

    function _stake(address staker, uint256 amount) internal {
        vm.startPrank(operatorAddress);
        prtHyEth.transfer(staker, amount);
        vm.startPrank(staker);
        prtHyEth.approve(address(snapshotStakingPool), amount);
        snapshotStakingPool.stake(amount);
    }

    function _unstake(address staker, uint256 amount) internal {
        vm.startPrank(staker);
        snapshotStakingPool.unstake(amount);
    }
}
