// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
 
import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/staking/SignedSnapshotStakingPool.sol";
 
contract DeploySignedSnapshotStakingPool is Script {

    string eip712Name = "Index Coop";
    string eip712Version = "V1";
    string stakeMessage = "I have read and accept the Terms of Service.";
    string name='High Yield ETH Index Staked PRT';
    string symbol='sPrtHyETH';
    IERC20 rewardToken= IERC20(0xc4506022Fb8090774E8A628d5084EED61D9B99Ee);
    IERC20 stakeToken= IERC20(0x99F6539Df9840592a862ab916dDc3258a1D7a773);
    uint256 stakeTokenDecimals= 18;
    address distributor= 0x43C3EF32E52f17777789c71002ef4a887df90613;
    uint256 public snapshotBuffer = 1 days;
    uint256 public snapshotDelay = 30 days;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        vm.startBroadcast(deployerPrivateKey);
 
        new SignedSnapshotStakingPool(
            eip712Name,
            eip712Version,
            stakeMessage,
            name,
            symbol,
            rewardToken,
            stakeToken,
            distributor,
            snapshotBuffer,
            snapshotDelay
        );
 
        vm.stopBroadcast();
    }
}
