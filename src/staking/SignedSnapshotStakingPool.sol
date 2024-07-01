// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignedSnapshotStakingPool} from "../interfaces/staking/ISignedSnapshotStakingPool.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {SnapshotStakingPool} from "./SnapshotStakingPool.sol";

/// @title SignedSnapshotStakingPool
/// @author Index Cooperative
/// @notice A contract for staking `stakeToken` and receiving `rewardToken` based 
/// on snapshots taken when rewards are accrued.
contract SignedSnapshotStakingPool is ISignedSnapshotStakingPool, SnapshotStakingPool, EIP712 {
    string private constant MESSAGE_TYPE = "StakeMessage(string message)";

    /* EVENTS */

    event StakerApproved(address indexed staker);

    /* STORAGE */

    /// @inheritdoc ISignedSnapshotStakingPool
    string public message;
    /// @inheritdoc ISignedSnapshotStakingPool
    mapping(address => bool) public isApprovedStaker;

    /* CONSTRUCTOR */

    /// @param eip712Name Name of the EIP712 signing domain
    /// @param eip712Version Current major version of the EIP712 signing domain
    /// @param stakeMessage The message to sign when staking
    /// @param name Name of the staked token
    /// @param symbol Symbol of the staked token
    /// @param rewardToken Instance of the reward token
    /// @param stakeToken Instance of the stake token
    /// @param distributor Address of the distributor
    /// @param snapshotDelay The minimum amount of time between snapshots
    constructor(
        string memory eip712Name,
        string memory eip712Version,
        string memory stakeMessage,
        string memory name,
        string memory symbol,
        IERC20 rewardToken,
        IERC20 stakeToken,
        address distributor,
        uint256 snapshotDelay
    )
        EIP712(eip712Name, eip712Version)
        SnapshotStakingPool(name, symbol, rewardToken, stakeToken, distributor, snapshotDelay)
    {
        message = stakeMessage;
    }

    /* STAKER FUNCTIONS */

    /// @inheritdoc ISignedSnapshotStakingPool
    function stake(uint256 _amount) external override(SnapshotStakingPool, ISignedSnapshotStakingPool) nonReentrant {
        require(isApprovedStaker[msg.sender], "Not approved staker");
        _stake(msg.sender, _amount);
    }

    /// @inheritdoc ISignedSnapshotStakingPool
    function stake(uint256 _amount, bytes calldata _signature) external nonReentrant {
        _approveStaker(msg.sender, _signature);
        _stake(msg.sender, _amount);
    }

    /// @inheritdoc ISignedSnapshotStakingPool
    function approveStaker(bytes calldata _signature) external {
        _approveStaker(msg.sender, _signature);
    }

    /* VIEW FUNCTIONS */

    /// @inheritdoc ISignedSnapshotStakingPool
    function getStakeSignatureDigest() public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(abi.encodePacked(MESSAGE_TYPE)),
                    keccak256(bytes(message))
                )
            )
        );
    }

    /* INTERNAL FUNCTIONS */

    /// @dev Approve the `staker` if the `signature` is valid
    /// @param staker The staker to approve
    /// @param signature The signature to verify
    function _approveStaker(address staker, bytes calldata signature) internal {
        require(SignatureChecker.isValidSignatureNow(staker, getStakeSignatureDigest(), signature), "Invalid signature");
        isApprovedStaker[staker] = true;
        emit StakerApproved(staker);
    }
}
