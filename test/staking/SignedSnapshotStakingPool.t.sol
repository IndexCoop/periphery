// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/mocks/ERC20Mock.sol";
import "../../src/staking/SignedSnapshotStakingPool.sol";

contract SignedSnapshotStakingPoolTest is Test {
    SignedSnapshotStakingPool public snapshotStakingPool;
    ERC20Mock public rewardToken;
    ERC20Mock public stakeToken;

    address public owner;
    VmSafe.Wallet alice = vm.createWallet("alice");
    VmSafe.Wallet bob = vm.createWallet("bob");
    VmSafe.Wallet carol = vm.createWallet("carol");
    address public distributor = address(0x5);

    uint256 public snapshotBuffer = 1 days;
    uint256 public snapshotDelay = 30 days;

    string public eip712Name = "Index Coop";
    string public eip712Version = "v1";
    string public message = "I have read and accept the Terms of Service.";

    function setUp() public {
        owner = msg.sender;
        rewardToken = new ERC20Mock();
        rewardToken.mint(owner, 1_000_000 ether);
        stakeToken = new ERC20Mock();
        stakeToken.mint(owner, 1_000_000 ether);
        snapshotStakingPool = new SignedSnapshotStakingPool(
            eip712Name,
            eip712Version,
            message,
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
        assertEq(snapshotStakingPool.message(), message);
    }

    function testStakeWithoutSignature() public {
        uint256 amount = 100 ether;

        bytes memory bobSignature = _signStakeMessage(bob);

        vm.prank(bob.addr);
        snapshotStakingPool.approveStaker(bobSignature);

        vm.prank(owner);
        stakeToken.transfer(bob.addr, amount);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);
        vm.prank(bob.addr);
        snapshotStakingPool.stake(amount);

        assertEq(stakeToken.balanceOf(bob.addr), 0);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), amount);

        vm.prank(alice.addr);
        vm.expectRevert(SignedSnapshotStakingPool.NotApprovedStaker.selector);
        snapshotStakingPool.stake(amount);

        bytes memory carolSignature = _signStakeMessage(carol);

        vm.prank(owner);
        stakeToken.transfer(carol.addr, amount);
        vm.prank(carol.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);
        vm.prank(carol.addr);
        snapshotStakingPool.stake(amount, carolSignature);

        vm.prank(owner);
        stakeToken.transfer(carol.addr, amount);
        vm.prank(carol.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);
        vm.prank(carol.addr);
        snapshotStakingPool.stake(amount);
    }

    function testStakeWithSignature() public {
        uint256 amount = 100 ether;

        bytes memory bobSignature = _signStakeMessage(bob);

        vm.prank(owner);
        stakeToken.transfer(bob.addr, amount);
        vm.prank(bob.addr);
        stakeToken.approve(address(snapshotStakingPool), amount);
        vm.prank(bob.addr);
        snapshotStakingPool.stake(amount, bobSignature);

        assertEq(stakeToken.balanceOf(bob.addr), 0);
        assertEq(snapshotStakingPool.balanceOf(bob.addr), amount);
        assert(snapshotStakingPool.isApprovedStaker(bob.addr));

        vm.prank(alice.addr);
        vm.expectRevert(SignedSnapshotStakingPool.InvalidSignature.selector);
        snapshotStakingPool.stake(amount, bobSignature);

    }

    function testApproveStaker() public {
        bytes memory bobSignature = _signStakeMessage(bob);

        vm.prank(bob.addr);
        vm.expectEmit();
        emit SignedSnapshotStakingPool.StakerApproved(bob.addr);
        snapshotStakingPool.approveStaker(bobSignature);

        assert(snapshotStakingPool.isApprovedStaker(bob.addr));

        vm.prank(alice.addr);
        vm.expectRevert(SignedSnapshotStakingPool.InvalidSignature.selector);
        snapshotStakingPool.approveStaker(bobSignature);
    }

    function testSetMessage() public {
        string memory newMessage = "I have read and accept the Privacy Policy.";

        vm.expectEmit();
        emit SignedSnapshotStakingPool.MessageChanged(newMessage);
        snapshotStakingPool.setMessage(newMessage);

        assertEq(snapshotStakingPool.message(), newMessage);

        vm.prank(bob.addr);
        vm.expectRevert("Ownable: caller is not the owner");
        snapshotStakingPool.setMessage(newMessage);
    }

    function _signStakeMessage(VmSafe.Wallet memory staker) internal returns (bytes memory) {
        bytes32 digest = snapshotStakingPool.getStakeSignatureDigest();
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
}
