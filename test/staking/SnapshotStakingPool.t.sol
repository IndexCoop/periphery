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
            snapshotDelay
        );
    }

    function testConstructor() public {
        assertEq(snapshotStakingPool.name(), "stakeToken Staking Pool");
        assertEq(snapshotStakingPool.symbol(), "stakeToken-POOL");
        assertEq(snapshotStakingPool.decimals(), 18);
        assertEq(address(snapshotStakingPool.stakeToken()), address(stakeToken));
        assertEq(address(snapshotStakingPool.distributor()), distributor);
        assertEq(snapshotStakingPool.snapshotDelay(), snapshotDelay);
    }

    function testSetDistributor() public {
        address newDistributor = address(0x6);
        snapshotStakingPool.setDistributor(newDistributor);
        assertEq(snapshotStakingPool.distributor(), newDistributor);

        vm.prank(bob.addr);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setDistributor(newDistributor);
    }

    function testSetSnapshotDelay() public {
        uint256 newSnapshotDelay = 365 days;
        snapshotStakingPool.setSnapshotDelay(newSnapshotDelay);
        assertEq(snapshotStakingPool.snapshotDelay(), newSnapshotDelay);

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

        vm.prank(bob.addr);
        vm.expectRevert("Cannot stake 0");
        snapshotStakingPool.stake(0);
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

        vm.prank(bob.addr);
        vm.expectRevert("Cannot unstake 0");
        snapshotStakingPool.unstake(0);
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
        vm.expectRevert("Snapshot delay not passed");
        snapshotStakingPool.accrue(amount);

        vm.prank(distributor);
        vm.expectRevert("Cannot accrue 0");
        snapshotStakingPool.accrue(0);

        vm.prank(bob.addr);
        snapshotStakingPool.unstake(amount);

        vm.prank(distributor);
        vm.expectRevert("Cannot accrue with 0 staked supply");
        snapshotStakingPool.accrue(amount);
    }

    function testClaim() public {
        uint256 bobAmount = 6 ether;
        uint256 aliceAmount = 4 ether;
        uint256 carolAmount = 5 ether;

        uint256 snap1Amount = 1 ether;
        uint256 snap2Amount = 1.5 ether;
        uint256 snap3Amount = 2 ether;

        _setUpStakingAndSnapshots(bobAmount, aliceAmount, carolAmount, snap1Amount, snap2Amount, snap3Amount);

        vm.prank(bob.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(bob.addr), 
            snap1Amount + 
            (bobAmount * snap2Amount / snapshotStakingPool.totalSupplyAt(2)) + 
            (bobAmount * snap3Amount / snapshotStakingPool.totalSupplyAt(3)) 
        );
        assertEq(snapshotStakingPool.nextClaimId(bob.addr), 4);

        vm.prank(alice.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(alice.addr), 
            (aliceAmount * snap2Amount / snapshotStakingPool.totalSupplyAt(2)) + 
            (aliceAmount * snap3Amount / snapshotStakingPool.totalSupplyAt(3)) 
        );
        assertEq(snapshotStakingPool.nextClaimId(alice.addr), 4);

        vm.prank(carol.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(carol.addr), 
            (carolAmount * snap2Amount / snapshotStakingPool.totalSupplyAt(2)) 
        );

        vm.prank(bob.addr);
        vm.expectRevert("Cannot claim from future snapshots");
        snapshotStakingPool.claim();

        vm.prank(alice.addr);
        snapshotStakingPool.unstake(aliceAmount);

        uint256 snap4Amount = 3 ether;
        vm.warp(block.timestamp + snapshotDelay);
        _snapshot(snap4Amount);

        vm.prank(bob.addr);
        snapshotStakingPool.claim();

        assertEq(rewardToken.balanceOf(bob.addr), 
            snap1Amount + 
            (bobAmount * snap2Amount / snapshotStakingPool.totalSupplyAt(2)) + 
            (bobAmount * snap3Amount / snapshotStakingPool.totalSupplyAt(3)) + 
            (bobAmount * snap4Amount / snapshotStakingPool.totalSupplyAt(4))
        );

        vm.prank(alice.addr);
        vm.expectRevert("No rewards to claim");
        snapshotStakingPool.claim();
    }

    function _setUpStakingAndSnapshots(
        uint256 bobAmount,
        uint256 aliceAmount,
        uint256 carolAmount,
        uint256 snap1Amount,
        uint256 snap2Amount,
        uint256 snap3Amount
    ) internal {
        vm.startPrank(owner);
        stakeToken.transfer(bob.addr, bobAmount);
        stakeToken.transfer(alice.addr, aliceAmount);
        stakeToken.transfer(carol.addr, carolAmount);
        vm.stopPrank();

        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), bobAmount);
        vm.prank(alice.addr);
        stakeToken.approve(address(snapshotStakingPool), aliceAmount);
        vm.prank(carol.addr);
        stakeToken.approve(address(snapshotStakingPool), carolAmount);

        vm.prank(bob.addr);
        snapshotStakingPool.stake(bobAmount);

        vm.warp(block.timestamp + snapshotDelay);
        _snapshot(snap1Amount);

        vm.prank(alice.addr);
        snapshotStakingPool.stake(aliceAmount);
        vm.prank(carol.addr);
        snapshotStakingPool.stake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay);

        _snapshot(snap2Amount);

        vm.prank(carol.addr);
        snapshotStakingPool.unstake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay + 1);

        _snapshot(snap3Amount);
    }

    function _snapshot(uint256 amount) internal {
        vm.prank(owner);
        rewardToken.transfer(distributor, amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(amount);
    }
}
