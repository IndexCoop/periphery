// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISnapshotStakingPool is IERC20 {

    /// @notice Token to be distributed as rewards
    function rewardToken() external view returns (IERC20);

    /// @notice Token to be staked
    function stakeToken() external view returns (IERC20);

    /// @notice Distributor of rewards
    function distributor() external view returns (address);

    /// @notice The buffer time before snapshots during which staking is not allowed
    function snapshotBuffer() external view returns (uint256);

    /// @notice The minimum amount of time between snapshots
    function snapshotDelay() external view returns (uint256);

    /// @notice Last snapshot time
    function lastSnapshotTime() external view returns (uint256);

    /// @notice Next snapshot id for `account` to claim
    function nextClaimId(address account) external view returns (uint256);

    /// @notice Reward snapshot at `snapshotId`
    function rewardSnapshots(uint256) external view returns (uint256);

    /// @notice Get the reward snapshots
    function getRewardSnapshots() external view returns (uint256[] memory);

    /// @notice Stake `amount` of stakeToken from `msg.sender` and mint staked tokens.
    /// @param amount The amount of stakeToken to stake
    function stake(uint256 amount) external;

    /// @notice Unstake `amount` of stakeToken by `msg.sender`.
    /// @param amount The amount of stakeToken to unstake
    function unstake(uint256 amount) external;

    /// @notice ONLY DISTRIBUTOR: Accrue rewardToken and update snapshot.
    /// @param amount The amount of rewardToken to accrue
    function accrue(uint256 amount) external;

    /// @notice Claim the staking rewards from pending snapshots for `msg.sender`.
    function claim() external;

    /// @notice Claim partial staking rewards from pending snapshots for `msg.sender` from `_startClaimId` to `_endClaimId`.
    /// @param startSnapshotId The snapshot id to start the partial claim
    /// @param endSnapshotId The snapshot id to end the partial claim
    function claimPartial(uint256 startSnapshotId, uint256 endSnapshotId) external;

    /// @notice ONLY OWNER: Update the distributor address.
    /// @param newDistributor The new distributor address
    function setDistributor(address newDistributor) external;

    /// @notice ONLY OWNER: Update the snapshot buffer.
    /// @param newSnapshotBuffer The new snapshot buffer
    function setSnapshotBuffer(uint256 newSnapshotBuffer) external;

    /// @notice ONLY OWNER: Update the snapshot delay. Can set to 0 to disable snapshot delay.
    /// @param newSnapshotDelay The new snapshot delay
    function setSnapshotDelay(uint256 newSnapshotDelay) external;

    /// @notice Get the current snapshot id.
    /// @return The current snapshot id
    function getCurrentSnapshotId() external view returns (uint256);

    /// @notice Retrieves the rewards pending to be claimed by `account`.
    /// @param account The account to retrieve pending rewards for
    /// @return The rewards pending to be claimed by `account`
    function getPendingRewards(address account) external view returns (uint256);

    /// @notice Retrives the rewards of `account` in the range of `startSnapshotId` to `endSnapshotId`.
    /// @param account The account to retrieve rewards for
    /// @param startSnapshotId The start snapshot id
    /// @param endSnapshotId The end snapshot id
    /// @return The rewards of `account` in the range of `startSnapshotId` to `endSnapshotId`
    function rewardOfInRange(address account, uint256 startSnapshotId, uint256 endSnapshotId) external view returns (uint256);

    /// @notice Retrieves the rewards of `account` at the `snapshotId`.
    /// @param account The account to retrieve rewards for
    /// @param snapshotId The snapshot id
    /// @return The rewards of `account` at the `snapshotId`
    function rewardOfAt(address account, uint256 snapshotId) external view returns (uint256);

    /// @notice Retrieves the total pool reward at the time `snapshotId`.
    /// @param snapshotId The snapshot id
    /// @return The total pool reward at the time `snapshotId`
    function rewardAt(uint256 snapshotId) external view returns (uint256);

    /// @notice Retrieves the rewards across all snapshots for `account`.
    /// @param account The account to retrieve rewards for
    /// @return The rewards across all snapshots for `account`
    function getLifetimeRewards(address account) external view returns (uint256);

    /// @notice Check if rewards can be accrued.
    /// @return Boolean indicating if rewards can be accrued
    function canAccrue() external view returns (bool);

    /// @notice Get the time until the next snapshot.
    /// @return The time until the next snapshot
    function getTimeUntilNextSnapshot() external view returns (uint256);

    /// @notice Get the next snapshot time.
    /// @return The next snapshot time
    function getNextSnapshotTime() external view returns (uint256);

    /// @notice Check if staking is allowed.
    /// @return Boolean indicating if staking is allowed
    function canStake() external view returns (bool);

    /// @notice Get the time until the next snapshot buffer begins.
    /// @return The time until the next snapshot buffer begins
    function getTimeUntilNextSnapshotBuffer() external view returns (uint256);

    /// @notice Get the next snapshot buffer time.
    /// @return The next snapshot buffer time
    function getNextSnapshotBufferTime() external view returns (uint256);
}
