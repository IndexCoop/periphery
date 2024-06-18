// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/mocks/ERC20Mock.sol";
import "../src/SnapshotStakingPool.sol";

contract SnapshotStakingPoolTest is Test {
    SnapshotStakingPool public snapshotStakingPool;
    ERC20Mock public setToken;
    ERC20Mock public stakeToken;

    address public owner = address(0x1);
    address public bob = address(0x2);
    address public alice = address(0x3);
    address public carol = address(0x4);
    address public distributor = address(0x5);

    uint256 public snapshotDelay = 30 days;
    string public eip712Name = "Index Coop";
    string public eip712Version = "v1";
    string public message = "Sign message";

    function setUp() public {
        setToken = new ERC20Mock();
        setToken.mint(owner, 1_000_000 ether);
        stakeToken = new ERC20Mock();
        stakeToken.mint(owner, 1_000_000 ether);
        snapshotStakingPool = new SnapshotStakingPool(
            eip712Name,
            eip712Version,
            message,
            "stakeToken Staking Pool",
            "stakeToken-POOL",
            IERC20(address(setToken)),
            IERC20(address(stakeToken)),
            distributor,
            snapshotDelay
        );
    }

    function signStakeMessage(address staker) internal returns (bytes memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(eip712Name)),
                keccak256(bytes(eip712Version)),
                block.chainid,
                address(snapshotStakingPool)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Stake(string message)"),
                keccak256(bytes(message))
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(uint160(staker)), digest);
        return abi.encodePacked(r, s, v);
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

        vm.prank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setDistributor(newDistributor);
    }

    function testSetSnapshotDelay() public {
        uint256 newSnapshotDelay = 365 days;
        snapshotStakingPool.setSnapshotDelay(newSnapshotDelay);
        assertEq(snapshotStakingPool.snapshotDelay(), newSnapshotDelay);

        vm.prank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setSnapshotDelay(newSnapshotDelay);
    }

    function testStake() public {
        uint256 amount = 1 ether;

        stakeToken.transfer(bob, amount);
        vm.prank(bob);
        stakeToken.approve(address(snapshotStakingPool), amount);

        bytes memory bobSignature = signStakeMessage(bob);

        vm.prank(bob);
        snapshotStakingPool.stake(amount, bobSignature);

        assertEq(stakeToken.balanceOf(address(snapshotStakingPool)), amount);
        assertEq(snapshotStakingPool.balanceOf(bob), amount);

        vm.prank(bob);
        vm.expectRevert("Transfers not allowed");
        snapshotStakingPool.transfer(owner, amount);
    }

    function testUnstake() public {
        uint256 amount = 1 ether;

        stakeToken.transfer(bob, amount);
        vm.prank(bob);
        stakeToken.approve(address(snapshotStakingPool), amount);

        bytes memory bobSignature = signStakeMessage(bob);

        vm.prank(bob);
        snapshotStakingPool.stake(amount, bobSignature);

        vm.prank(bob);
        snapshotStakingPool.unstake(amount);

        assertEq(stakeToken.balanceOf(bob), amount);
        assertEq(snapshotStakingPool.balanceOf(bob), 0);
    }

    function testAccrue() public {
        uint256 amount = 1 ether;

        stakeToken.transfer(bob, amount);
        vm.prank(bob);
        stakeToken.approve(address(snapshotStakingPool), amount);

        bytes memory bobSignature = signStakeMessage(bob);

        vm.prank(bob);
        snapshotStakingPool.stake(amount, bobSignature);

        setToken.transfer(distributor, amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), amount);

        vm.prank(distributor);
        snapshotStakingPool.accrue(amount);

        assertEq(setToken.balanceOf(address(snapshotStakingPool)), amount);
    }

    function testClaim() public {
        uint256 bobAmount = 6 ether;
        uint256 aliceAmount = 4 ether;
        uint256 carolAmount = 5 ether;
        uint256 snap1Amount = 1 ether;
        uint256 snap2Amount = 1.5 ether;
        uint256 snap3Amount = 2 ether;

        stakeToken.transfer(bob, bobAmount);
        stakeToken.transfer(alice, aliceAmount);
        stakeToken.transfer(carol, carolAmount);

        vm.prank(bob);
        stakeToken.approve(address(snapshotStakingPool), bobAmount);
        vm.prank(alice);
        stakeToken.approve(address(snapshotStakingPool), aliceAmount);
        vm.prank(carol);
        stakeToken.approve(address(snapshotStakingPool), carolAmount);

        bytes memory bobSignature = signStakeMessage(bob);
        bytes memory aliceSignature = signStakeMessage(alice);
        bytes memory carolSignature = signStakeMessage(carol);

        vm.prank(bob);
        snapshotStakingPool.stake(bobAmount, bobSignature);

        setToken.transfer(distributor, snap1Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap1Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap1Amount);

        vm.prank(alice);
        snapshotStakingPool.stake(aliceAmount, aliceSignature);
        vm.prank(carol);
        snapshotStakingPool.stake(carolAmount, carolSignature);

        vm.warp(block.timestamp + snapshotDelay);

        setToken.transfer(distributor, snap2Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap2Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap2Amount);

        vm.prank(carol);
        snapshotStakingPool.unstake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay);

        setToken.transfer(distributor, snap3Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap3Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap3Amount);

        vm.prank(bob);
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

        stakeToken.transfer(bob, bobAmount);
        stakeToken.transfer(alice, aliceAmount);
        stakeToken.transfer(carol, carolAmount);

        vm.prank(bob);
        stakeToken.approve(address(snapshotStakingPool), bobAmount);
        vm.prank(alice);
        stakeToken.approve(address(snapshotStakingPool), aliceAmount);
        vm.prank(carol);
        stakeToken.approve(address(snapshotStakingPool), carolAmount);

        bytes memory bobSignature = signStakeMessage(bob);
        bytes memory aliceSignature = signStakeMessage(alice);
        bytes memory carolSignature = signStakeMessage(carol);

        vm.prank(bob);
        snapshotStakingPool.stake(bobAmount, bobSignature);

        setToken.transfer(distributor, snap1Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap1Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap1Amount);

        vm.prank(alice);
        snapshotStakingPool.stake(aliceAmount, aliceSignature);
        vm.prank(carol);
        snapshotStakingPool.stake(carolAmount, carolSignature);

        vm.warp(block.timestamp + snapshotDelay);

        setToken.transfer(distributor, snap2Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap2Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap2Amount);

        vm.prank(carol);
        snapshotStakingPool.unstake(carolAmount);

        vm.warp(block.timestamp + snapshotDelay);

        setToken.transfer(distributor, snap3Amount);
        vm.prank(distributor);
        setToken.approve(address(snapshotStakingPool), snap3Amount);
        vm.prank(distributor);
        snapshotStakingPool.accrue(snap3Amount);

        vm.prank(bob);
        snapshotStakingPool.claimPartial(0, 2);

        // More assertions can be added here to verify the partial claim logic
    }
}
