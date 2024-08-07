// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/mocks/ERC20Mock.sol";
import "../../src/staking/SnapshotStakingPool.sol";

contract SnapshotStakingPoolTest is Test {
    SnapshotStakingPool public snapshotStakingPool;
    ERC20Mock public rewardToken;
    ERC20Mock public stakeToken;

    address public owner;
    VmSafe.Wallet alice = vm.createWallet("alice");
    VmSafe.Wallet bob = vm.createWallet("bob");
    VmSafe.Wallet carol = vm.createWallet("carol");
    address public distributor = address(0x5);

    uint256 public snapshotBuffer = 1 days;
    uint256 public snapshotDelay = 30 days;

    function setUp() public {
        owner = msg.sender;
        rewardToken = new ERC20Mock();
        rewardToken.mint(owner, 1_000_000 ether);
        stakeToken = new ERC20Mock();
        stakeToken.mint(owner, 1_000_000 ether);
        snapshotStakingPool = new SnapshotStakingPool(
            "stakeToken Staking Pool",
            "stakeToken-POOL",
            IERC20(address(rewardToken)),
            IERC20(address(stakeToken)),
            distributor,
            snapshotBuffer,
            snapshotDelay
        );
    }

    function testConstructor() public {
        assertEq(snapshotStakingPool.name(), "stakeToken Staking Pool");
        assertEq(snapshotStakingPool.symbol(), "stakeToken-POOL");
        assertEq(snapshotStakingPool.decimals(), 18);
        assertEq(address(snapshotStakingPool.stakeToken()), address(stakeToken));
        assertEq(address(snapshotStakingPool.distributor()), distributor);
        assertEq(snapshotStakingPool.snapshotBuffer(), snapshotBuffer);
        assertEq(snapshotStakingPool.snapshotDelay(), snapshotDelay);
        assertEq(snapshotStakingPool.lastSnapshotTime(), block.timestamp);

        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotBuffer.selector);
        new SnapshotStakingPool(
            "stakeToken Staking Pool",
            "stakeToken-POOL",
            IERC20(address(rewardToken)),
            IERC20(address(stakeToken)),
            distributor,
            snapshotDelay + 1,
            snapshotDelay
        );
    }

    function testSetDistributor() public {
        address newDistributor = address(0x6);

        vm.expectEmit();
        emit SnapshotStakingPool.DistributorChanged(newDistributor);
        snapshotStakingPool.setDistributor(newDistributor);

        assertEq(snapshotStakingPool.distributor(), newDistributor);

        vm.prank(bob.addr);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setDistributor(newDistributor);
    }

    function testSetSnapshotBuffer() public {
        uint256 newSnapshotBuffer = 2 days;

        vm.expectEmit();
        emit SnapshotStakingPool.SnapshotBufferChanged(newSnapshotBuffer);
        snapshotStakingPool.setSnapshotBuffer(newSnapshotBuffer);

        assertEq(snapshotStakingPool.snapshotBuffer(), newSnapshotBuffer);

        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotBuffer.selector);
        snapshotStakingPool.setSnapshotBuffer(snapshotDelay + 1);

        vm.prank(bob.addr);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setSnapshotBuffer(newSnapshotBuffer);
    }

    function testSetSnapshotDelay() public {
        uint256 newSnapshotDelay = 365 days;

        vm.expectEmit();
        emit SnapshotStakingPool.SnapshotDelayChanged(newSnapshotDelay);
        snapshotStakingPool.setSnapshotDelay(newSnapshotDelay);

        assertEq(snapshotStakingPool.snapshotDelay(), newSnapshotDelay);

        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotDelay.selector);
        snapshotStakingPool.setSnapshotDelay(snapshotBuffer - 1);

        vm.prank(bob.addr);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setSnapshotDelay(newSnapshotDelay);
    }

    function testStake() public {
        uint256 amount = 1 ether;

        vm.prank(owner);
        stakeToken.transfer(bob.addr, amount);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);

        vm.prank(bob.addr);
        snapshotStakingPool.stake(amount);

        assertEq(stakeToken.balanceOf(address(snapshotStakingPool)), amount);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), amount);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 1);
        assertEq(snapshotStakingPool.getCurrentSnapshotId(), 0);

        _snapshot(1 ether);
        _snapshot(1 ether);

        vm.prank(owner);
        stakeToken.transfer(alice.addr, amount);
        vm.prank(alice.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);

        vm.prank(alice.addr);
        snapshotStakingPool.stake(amount);

        assertEq(snapshotStakingPool.nextClaimId(alice.addr), snapshotStakingPool.getCurrentSnapshotId());

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer);
        vm.expectRevert(SnapshotStakingPool.CannotStakeDuringBuffer.selector);
        snapshotStakingPool.stake(amount);
    }

    function testUnstake() public {
        uint256 amount = 1 ether;

        vm.prank(owner);
        stakeToken.transfer(bob.addr, amount);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);

        vm.prank(bob.addr);
        snapshotStakingPool.stake(amount);

        vm.prank(bob.addr);
        snapshotStakingPool.unstake(amount);

        assertEq(stakeToken.balanceOf(bob.addr), amount);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), 0);
    }

    function testAccrue() public {
        uint256 amount = 1 ether;

        vm.prank(owner);
        stakeToken.transfer(bob.addr, amount);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);

        vm.prank(bob.addr);
        snapshotStakingPool.stake(amount);

        vm.prank(owner);
        rewardToken.transfer(distributor, amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), amount);

        vm.warp(block.timestamp + snapshotDelay + 1);
        vm.prank(distributor);
        snapshotStakingPool.accrue(amount);

        assertEq(rewardToken.balanceOf(address(snapshotStakingPool)), amount);
        assertEq(snapshotStakingPool.rewardSnapshots(0), amount);
        assertEq(snapshotStakingPool.lastSnapshotTime(), block.timestamp);
        assertEq(snapshotStakingPool.getCurrentSnapshotId(), 1);

        vm.prank(distributor);
        vm.expectRevert(SnapshotStakingPool.SnapshotDelayNotPassed.selector);
        snapshotStakingPool.accrue(amount);

        vm.prank(distributor);
        vm.expectRevert(SnapshotStakingPool.CannotAccrueZero.selector);
        snapshotStakingPool.accrue(0);

        vm.prank(bob.addr);
        snapshotStakingPool.unstake(amount);

        vm.prank(distributor);
        vm.expectRevert(SnapshotStakingPool.CannotAccrueWithZeroStakedSupply.selector);
        snapshotStakingPool.accrue(amount);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.MustBeDistributor.selector);
        snapshotStakingPool.accrue(amount);
    }

    function testGetCurrentSnapshotId() public {
        assertEq(snapshotStakingPool.getCurrentSnapshotId(), 0);

        _stake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getCurrentSnapshotId(), 1);
    }

    function testRewardAt() public {
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.rewardAt(0);

        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardAt(1);

        _stake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.rewardAt(1), 1 ether);

        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardAt(2);
    }

    function testRewardOfAt() public {
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.rewardOfAt(bob.addr, 0);

        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardOfAt(bob.addr, 1);

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.rewardOfAt(bob.addr, 1), 0.5 ether);
        assertEq(snapshotStakingPool.rewardOfAt(alice.addr, 1), 0.5 ether);

        _unstake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.rewardOfAt(bob.addr, 2), 0);
        assertEq(snapshotStakingPool.rewardOfAt(alice.addr, 2), 1 ether);

        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardOfAt(bob.addr, 3);
    }

    function testRewardOfInRange() public {
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.rewardOfInRange(bob.addr, 0, 0);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.rewardOfInRange(bob.addr, 0, 1);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardOfInRange(bob.addr, 1, 1);

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);
        _snapshot(2 ether);

        assertEq(snapshotStakingPool.rewardOfInRange(bob.addr, 1, 1), 1 ether);
        assertEq(snapshotStakingPool.rewardOfInRange(alice.addr, 1, 1), 1 ether);

        _snapshot(2 ether);
        _snapshot(2 ether);

        assertEq(snapshotStakingPool.rewardOfInRange(bob.addr, 1, 2), 2 ether);
        assertEq(snapshotStakingPool.rewardOfInRange(alice.addr, 1, 3), 3 ether);

        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.rewardOfInRange(bob.addr, 1, 4);
    }

    function testGetPendingRewards() public {
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 0);

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 0);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), 0);

        _snapshot(2 ether);
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 1 ether);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), 1 ether);

        vm.prank(bob.addr);
        snapshotStakingPool.claim();
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 0);

        _snapshot(1 ether);
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 0.5 ether);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), 1.5 ether);

        _snapshot(2 ether);
        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 1.5 ether);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), 2.5 ether);

        _unstake(alice.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getPendingRewards(bob.addr), 2.5 ether);
        assertEq(snapshotStakingPool.getPendingRewards(alice.addr), 2.5 ether);
    }

    function testGetRewardSnapshots() public {
        assertEq(snapshotStakingPool.getRewardSnapshots().length, 0);

        _stake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getRewardSnapshots().length, 1);
        assertEq(snapshotStakingPool.getRewardSnapshots()[0], 1 ether);

        _snapshot(2 ether);

        assertEq(snapshotStakingPool.getRewardSnapshots().length, 2);
        assertEq(snapshotStakingPool.getRewardSnapshots()[0], 1 ether);
        assertEq(snapshotStakingPool.getRewardSnapshots()[1], 2 ether);
    }

    function testGetLifetimeRewards() public {
        assertEq(snapshotStakingPool.getLifetimeRewards(bob.addr), 0);

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);

        assertEq(snapshotStakingPool.getLifetimeRewards(bob.addr), 0);
        assertEq(snapshotStakingPool.getLifetimeRewards(alice.addr), 0);

        _snapshot(2 ether);

        assertEq(snapshotStakingPool.getLifetimeRewards(bob.addr), 1 ether);
        assertEq(snapshotStakingPool.getLifetimeRewards(alice.addr), 1 ether);

        _snapshot(2 ether);

        assertEq(snapshotStakingPool.getLifetimeRewards(bob.addr), 2 ether);
        assertEq(snapshotStakingPool.getLifetimeRewards(alice.addr), 2 ether);

        _unstake(alice.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getLifetimeRewards(bob.addr), 3 ether);
        assertEq(snapshotStakingPool.getLifetimeRewards(alice.addr), 2 ether);
    }

    function testCanAccrue() public {
        assertEq(snapshotStakingPool.canAccrue(), false);

        _stake(bob.addr, 1 ether);

        vm.warp(block.timestamp + snapshotDelay + 1);
        assertEq(snapshotStakingPool.canAccrue(), true);

        _snapshot(1 ether);

        assertEq(snapshotStakingPool.canAccrue(), false);

        vm.warp(block.timestamp + snapshotDelay + 1);
        assertEq(snapshotStakingPool.canAccrue(), true);
    }

    function testGetTimeUntilNextSnapshot() public {
        _stake(bob.addr, 1 ether);

        vm.warp(block.timestamp + snapshotDelay + 1);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshot(), 0);

        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getTimeUntilNextSnapshot(), snapshotDelay);

        vm.warp(block.timestamp + snapshotDelay - 10);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshot(), 10);
    }

    function testGetNextSnapshotTime() public {
        uint256 oldSnapshotTime = snapshotStakingPool.getNextSnapshotTime();
        assertEq(oldSnapshotTime, block.timestamp + snapshotDelay);

        _stake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getNextSnapshotTime(), block.timestamp + snapshotDelay);
        assert(oldSnapshotTime < snapshotStakingPool.getNextSnapshotTime());
    }

    function testCanStake() public {
        assertEq(snapshotStakingPool.canStake(), true);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer - 1);
        assertEq(snapshotStakingPool.canStake(), true);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer);
        assertEq(snapshotStakingPool.canStake(), false);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer + 1);
        assertEq(snapshotStakingPool.canStake(), false);
    }

    function testGetTimeUntilNextSnapshotBuffer() public {
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), snapshotDelay - snapshotBuffer);

        _stake(bob.addr, 1 ether);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer - 1);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), 1);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), 0);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer + 1);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), 0);

        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), snapshotDelay - snapshotBuffer);

        vm.warp(block.timestamp + snapshotDelay - snapshotBuffer - 10);
        assertEq(snapshotStakingPool.getTimeUntilNextSnapshotBuffer(), 10);
    }

    function testGetNextSnapshotBufferTime() public {
        uint256 oldSnapshotBuffer = snapshotStakingPool.getNextSnapshotBufferTime();
        assertEq(oldSnapshotBuffer, block.timestamp + snapshotDelay - snapshotBuffer);

        _stake(bob.addr, 1 ether);
        _snapshot(1 ether);

        assertEq(snapshotStakingPool.getNextSnapshotBufferTime(), block.timestamp + snapshotDelay - snapshotBuffer);
        assert(oldSnapshotBuffer < snapshotStakingPool.getNextSnapshotBufferTime());
    }

    function testClaim() public {
        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.claim();

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);
        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.claim();

        _snapshot(2 ether);
        vm.prank(bob.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(bob.addr), 1 ether);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 2);

        _snapshot(2 ether);
        vm.prank(bob.addr);
        snapshotStakingPool.claim();
        vm.prank(alice.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(bob.addr), 2 ether);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 3);
        assertEq(rewardToken.balanceOf(alice.addr), 2 ether);
        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 3);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.claim();
        vm.prank(alice.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.claim();

        _snapshot(1 ether);
        _unstake(alice.addr, 1 ether);
        _snapshot(1 ether);
        _snapshot(1 ether);

        vm.prank(alice.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(alice.addr), 2.5 ether);
        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 6);

        vm.prank(bob.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(bob.addr), 4.5 ether);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 6);
    }

    function testClaimPartial() public {
        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.claimPartial(0, 0);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.InvalidSnapshotId.selector);
        snapshotStakingPool.claimPartial(0, 1);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.claimPartial(1, 1);

        _stake(bob.addr, 1 ether);
        _stake(alice.addr, 1 ether);
        _snapshot(2 ether);

        vm.prank(bob.addr);
        snapshotStakingPool.claimPartial(1, 1);

        assertEq(rewardToken.balanceOf(bob.addr), 1 ether);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 2);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.CannotClaimFromPastSnapshots.selector);
        snapshotStakingPool.claimPartial(1, 1);

        _snapshot(2 ether);
        _snapshot(2 ether);

        vm.prank(alice.addr);
        snapshotStakingPool.claimPartial(1, 2);

        assertEq(rewardToken.balanceOf(alice.addr), 2 ether);
        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 3);

        vm.prank(alice.addr);
        snapshotStakingPool.claimPartial(3, 3);

        assertEq(rewardToken.balanceOf(alice.addr), 3 ether);
        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 4);

        vm.prank(alice.addr);
        vm.expectRevert(SnapshotStakingPool.CannotClaimFromPastSnapshots.selector);
        snapshotStakingPool.claimPartial(1, 3);

        vm.prank(alice.addr);
        vm.expectRevert(SnapshotStakingPool.NonExistentSnapshotId.selector);
        snapshotStakingPool.claimPartial(4, 4);

        _unstake(bob.addr, 1 ether);
        _snapshot(1 ether);
        _snapshot(1 ether);

        vm.prank(bob.addr);
        snapshotStakingPool.claimPartial(2, 5);

        assertEq(rewardToken.balanceOf(bob.addr), 3 ether);
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 6);
    }

    function testTransfer() public {
        _stake(bob.addr, 1 ether);

        vm.prank(bob.addr);
        vm.expectRevert(SnapshotStakingPool.TransfersNotAllowed.selector);
        snapshotStakingPool.transfer(alice.addr, 1 ether);
    }

    function testTransferFrom() public {
        _stake(bob.addr, 1 ether);

        vm.prank(bob.addr);
        snapshotStakingPool.approve(alice.addr, 1 ether);

        vm.prank(alice.addr);
        vm.expectRevert(SnapshotStakingPool.TransfersNotAllowed.selector);
        snapshotStakingPool.transferFrom(bob.addr, alice.addr, 1 ether);
    }

    function _snapshot(uint256 amount) internal {
        vm.prank(owner);
        rewardToken.transfer(distributor, amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), amount);
        vm.prank(distributor);
        vm.warp(block.timestamp + snapshotDelay + 1);
        snapshotStakingPool.accrue(amount);
    }

    function _stake(address staker, uint256 amount) internal {
        vm.prank(owner);
        stakeToken.transfer(staker, amount);
        vm.prank(staker);
        stakeToken.approve(address(snapshotStakingPool), amount);
        vm.prank(staker);
        snapshotStakingPool.stake(amount);
    }

    function _unstake(address staker, uint256 amount) internal {
        vm.prank(staker);
        snapshotStakingPool.unstake(amount);
    }
}
