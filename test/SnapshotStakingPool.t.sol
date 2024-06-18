// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/mocks/ERC20Mock.sol";
import "../src/SnapshotStakingPool.sol";

contract SnapshotStakingPoolTest is Test {

    uint256 constant DEFAULT_DEADLINE_SECONDS = 10;

    SnapshotStakingPool public snapshotStakingPool;
    ERC20Mock public rewardToken;
    ERC20Mock public stakeToken;

    address public owner;
    VmSafe.Wallet alice = vm.createWallet("alice");
    VmSafe.Wallet bob = vm.createWallet("bob");
    VmSafe.Wallet carol = vm.createWallet("carol");
    address public distributor = address(0x5);

    uint256 public snapshotDelay = 30 days;
    string public eip712Name = "Index Coop";
    string public eip712Version = "v1";

    function setUp() public {
        owner = msg.sender;
        rewardToken = new ERC20Mock();
        rewardToken.mint(owner, 1_000_000 ether);
        stakeToken = new ERC20Mock();
        stakeToken.mint(owner, 1_000_000 ether);
        snapshotStakingPool = new SnapshotStakingPool(
            eip712Name,
            eip712Version,
            "stakeToken Staking Pool",
            "stakeToken-POOL",
            IERC20(address(rewardToken)),
            IERC20(address(stakeToken)),
            distributor,
            snapshotDelay
        );
    }

    function signStakeMessage(VmSafe.Wallet memory staker, uint256 deadline, uint256 amount) internal returns (bytes memory) {

        bytes32 digest = snapshotStakingPool.getStakeSignatureDigest(staker.addr, deadline, amount);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(staker, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes32 r_recovered;
        bytes32 s_recovered;
        uint8 v_recovered;
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r_recovered := mload(add(signature, 0x20))
            s_recovered := mload(add(signature, 0x40))
            v_recovered := byte(0, mload(add(signature, 0x60)))
        }
        assertEq(v, v_recovered);
        assertEq(r, r_recovered);
        assertEq(s, s_recovered);
        return signature;

    }


    function stake(uint256 amount, VmSafe.Wallet memory staker) internal {
        stake(amount, block.timestamp + DEFAULT_DEADLINE_SECONDS, staker);
    }

    function stake(uint256 amount, uint256 deadline, VmSafe.Wallet memory staker) internal {
        vm.prank(owner);
        stakeToken.transfer(staker.addr, amount);
        vm.prank(staker.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);

        bytes memory signature = signStakeMessage(staker, deadline, amount);
        snapshotStakingPool.stake(amount, signature, staker.addr, deadline);
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
        stakeToken.transfer(bob.addr, amount * 2);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount * 2);
 
        uint256 deadline = block.timestamp + DEFAULT_DEADLINE_SECONDS;
        bytes memory bobSignature = signStakeMessage(bob, deadline, amount);

        // Check that stake message can be submitted by someone else
        vm.prank(carol.addr);
        snapshotStakingPool.stake(amount, bobSignature, bob.addr, deadline);

        assertEq(stakeToken.balanceOf(address(snapshotStakingPool)), amount);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), amount);

        // Check that signature cannot be replayed
        vm.expectRevert("Invalid signature");
        snapshotStakingPool.stake(amount, bobSignature, bob.addr, deadline);

        // Check that user can stake again with new signature
        deadline = block.timestamp + DEFAULT_DEADLINE_SECONDS;
        bobSignature = signStakeMessage(bob, deadline, amount);
        snapshotStakingPool.stake(amount, bobSignature, bob.addr, deadline);
        assertEq(stakeToken.balanceOf(address(snapshotStakingPool)), amount * 2);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), amount * 2);

        vm.prank(bob.addr);
        vm.expectRevert("Transfers not allowed");
        snapshotStakingPool.transfer(owner, amount);
    }

    function testUnstake() public {
        uint256 amount = 1 ether;

        stake(amount, bob);

        vm.prank(bob.addr);
        snapshotStakingPool.unstake(amount);

        assertEq(stakeToken.balanceOf(bob.addr), amount);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), 0);
    }

    function testAccrue() public {
        uint256 amount = 1 ether;

        stake(amount, bob);

        vm.prank(owner);
        rewardToken.transfer(distributor, amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), amount);

        vm.warp(block.timestamp + snapshotDelay + 1);
        vm.prank(distributor);
        snapshotStakingPool.accrue(amount);

        assertEq(rewardToken.balanceOf(address(snapshotStakingPool)), amount);
    }

    function testClaim() public {
        uint256 bobAmount = 6 ether;
        uint256 aliceAmount = 4 ether;
        uint256 carolAmount = 5 ether;
        uint256 snap1Amount = 1 ether;
        uint256 snap2Amount = 1.5 ether;
        uint256 snap3Amount = 2 ether;


        stake(bobAmount, bob);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap1Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap1Amount);
        vm.warp(block.timestamp + snapshotDelay);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap1Amount);

        stake(aliceAmount, alice);
        stake(carolAmount, carol);

        vm.warp(block.timestamp + snapshotDelay);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap2Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap2Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap2Amount);

        vm.prank(carol.addr);
        snapshotStakingPool.unstake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay + 1);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap3Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap3Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap3Amount);

        vm.prank(bob.addr);
        snapshotStakingPool.claim();

        // More assertions can be added here to verify the claim logic
    }

    function testClaimPartial() public {
        uint256 bobAmount = 6 ether;
        uint256 aliceAmount = 4 ether;
        uint256 carolAmount = 5 ether;
        uint256 snap1Amount = 1 ether;
        uint256 snap2Amount = 1.5 ether;
        uint256 snap3Amount = 2 ether;

        stake(bobAmount, bob);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap1Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap1Amount);
        vm.prank(distributor);
        vm.warp(block.timestamp + snapshotDelay);
        snapshotStakingPool.accrue(snap1Amount);

        stake(aliceAmount, alice);
        stake(carolAmount, carol);

        vm.warp(block.timestamp + snapshotDelay);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap2Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap2Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap2Amount);

        vm.prank(carol.addr);
        snapshotStakingPool.unstake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay);

        vm.prank(owner);
        rewardToken.transfer(distributor, snap3Amount);
        vm.prank(distributor);
        rewardToken.approve(address(snapshotStakingPool), snap3Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap3Amount);

        vm.prank(bob.addr);
        snapshotStakingPool.claimPartial(0, 2);

        // More assertions can be added here to verify the partial claim logic
    }
}