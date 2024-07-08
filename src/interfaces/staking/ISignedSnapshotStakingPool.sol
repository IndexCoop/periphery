// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ISnapshotStakingPool} from "./ISnapshotStakingPool.sol";

interface ISignedSnapshotStakingPool is ISnapshotStakingPool {

    /// @notice Message to sign when staking
    function message() external view returns (string memory);

    /// @notice Mapping of approved stakers
    function isApprovedStaker(address) external view returns (bool);

    /// @notice Stake `amount` of stakeToken from `msg.sender` and mint staked tokens.
    /// @param amount The amount of stakeToken to stake
    /// @dev Must be an approved staker
    function stake(uint256 amount) external;

    /// @notice Stake `amount` of stakeToken from `msg.sender` and mint staked tokens.
    /// @param amount The amount of stakeToken to stake
    /// @param signature The signature of the message
    /// @dev Approves the staker if not already approved
    function stake(uint256 amount, bytes calldata signature) external;

    /// @notice Approve the signer of the message as an approved staker
    /// @param signature The signature of the message
    function approveStaker(bytes calldata signature) external;

    /// @notice Set the message to sign when staking
    /// @param newMessage The new message
    function setMessage(string memory newMessage) external;

    /// @notice Get the hashed digest of the message to be signed for staking
    /// @return The hashed bytes to be signed
    function getStakeSignatureDigest() external view returns (bytes32);
}
