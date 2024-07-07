// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISnapshotStakingPool} from "../interfaces/staking/ISnapshotStakingPool.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title SnapshotStakingPool
/// @author Index Cooperative
/// @notice A contract for staking `stakeToken` and receiving `rewardToken` based 
/// on snapshots taken when rewards are accrued.
contract SnapshotStakingPool is ISnapshotStakingPool, Ownable, ERC20Snapshot, ReentrancyGuard {

    /* ERRORS */

    /// @notice Error when snapshot buffer is greater than snapshot delay
    error InvalidSnapshotBuffer(); 
    /// @notice Error when snapshot delay is less than snapshot buffer
    error InvalidSnapshotDelay(); 
    /// @notice Error when staking during snapshot buffer period
    error CannotStakeDuringBuffer();
    /// @notice Error when accrue is called by non-distributor
    error MustBeDistributor();
    /// @notice Error when trying to accrue zero rewards
    error CannotAccrueZero();
    /// @notice Error when trying to accrue rewards with zero staked supply
    error CannotAccrueWithZeroStakedSupply();
    /// @notice Error when trying to accrue rewards before snapshot delay
    error SnapshotDelayNotPassed();
    /// @notice Error when trying to claim rewards from past snapshots
    error CannotClaimFromPastSnapshots();
    /// @notice Error when snapshot id is invalid
    error InvalidSnapshotId();
    /// @notice Error when snapshot id does not exist
    error NonExistentSnapshotId();
    /// @notice Error when transfers are attempted
    error TransfersNotAllowed();

    /* EVENTS */

    /// @notice Emitted when the reward distributor is changed.
    event DistributorChanged(address newDistributor);
    /// @notice Emitted when the snapshot buffer is changed.
    event SnapshotBufferChanged(uint256 newSnapshotBuffer);
    /// @notice Emitted when the snapshot delay is changed.
    event SnapshotDelayChanged(uint256 newSnapshotDelay);

    /* IMMUTABLES */

    /// @inheritdoc ISnapshotStakingPool
    IERC20 public immutable rewardToken;
    /// @inheritdoc ISnapshotStakingPool
    IERC20 public immutable stakeToken;

    /* STORAGE */

    /// @inheritdoc ISnapshotStakingPool
    address public distributor;
    /// @inheritdoc ISnapshotStakingPool
    mapping(address => uint256) public nextClaimId;
    /// @inheritdoc ISnapshotStakingPool
    uint256[] public rewardSnapshots;
    /// @inheritdoc ISnapshotStakingPool
    uint256 public snapshotBuffer;
    /// @inheritdoc ISnapshotStakingPool
    uint256 public snapshotDelay;
    /// @inheritdoc ISnapshotStakingPool
    uint256 public lastSnapshotTime;

    /* CONSTRUCTOR */

    /// @param _name Name of the staked token
    /// @param _symbol Symbol of the staked token
    /// @param _rewardToken Instance of the reward token
    /// @param _stakeToken Instance of the stake token
    /// @param _distributor Address of the distributor
    /// @param _snapshotBuffer The buffer time before snapshots during which staking is not allowed
    /// @param _snapshotDelay The minimum amount of time between snapshots
    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        IERC20 _stakeToken,
        address _distributor,
        uint256 _snapshotBuffer,
        uint256 _snapshotDelay
    )
        ERC20(_name, _symbol)
    {
        if (_snapshotBuffer > _snapshotDelay) revert InvalidSnapshotBuffer();
        rewardToken = _rewardToken;
        stakeToken = _stakeToken;
        distributor = _distributor;
        snapshotBuffer = _snapshotBuffer;
        snapshotDelay = _snapshotDelay;
        lastSnapshotTime = block.timestamp;
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the distributor.
    modifier onlyDistributor() {
        if (msg.sender != distributor) revert MustBeDistributor();
        _;
    }

    /* STAKER FUNCTIONS */

    /// @inheritdoc ISnapshotStakingPool
    function stake(uint256 amount) external virtual nonReentrant {
        _stake(msg.sender, amount);
    }

    /// @inheritdoc ISnapshotStakingPool
    function unstake(uint256 amount) public nonReentrant {
        super._burn(msg.sender, amount);
        stakeToken.transfer(msg.sender, amount);
    }

    /// @inheritdoc ISnapshotStakingPool
    function accrue(uint256 amount) external nonReentrant onlyDistributor {
        if (amount == 0) revert CannotAccrueZero();
        if (totalSupply() == 0) revert CannotAccrueWithZeroStakedSupply();
        if (!canAccrue()) revert SnapshotDelayNotPassed();
        rewardToken.transferFrom(msg.sender, address(this), amount);
        lastSnapshotTime = block.timestamp;
        rewardSnapshots.push(amount);
        super._snapshot();
    }

    /// @inheritdoc ISnapshotStakingPool
    function claim() public nonReentrant {
        uint256 currentId = _getCurrentSnapshotId();
        uint256 lastId = nextClaimId[msg.sender];
        _claim(msg.sender, lastId, currentId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function claimPartial(uint256 startSnapshotId, uint256 endSnapshotId) public nonReentrant {
        if (startSnapshotId < nextClaimId[msg.sender]) revert CannotClaimFromPastSnapshots();
        _claim(msg.sender, startSnapshotId, endSnapshotId);
    }

    /* ADMIN FUNCTIONS */

    /// @inheritdoc ISnapshotStakingPool
    function setDistributor(address newDistributor) external onlyOwner {
        distributor = newDistributor;
        emit DistributorChanged(newDistributor);
    }

    /// @inheritdoc ISnapshotStakingPool
    function setSnapshotBuffer(uint256 newSnapshotBuffer) external onlyOwner {
        if (newSnapshotBuffer > snapshotDelay) revert InvalidSnapshotBuffer();
        snapshotBuffer = newSnapshotBuffer;
        emit SnapshotBufferChanged(newSnapshotBuffer);
    }

    /// @inheritdoc ISnapshotStakingPool
    function setSnapshotDelay(uint256 newSnapshotDelay) external onlyOwner {
        if (snapshotBuffer > newSnapshotDelay) revert InvalidSnapshotDelay();
        snapshotDelay = newSnapshotDelay;
        emit SnapshotDelayChanged(newSnapshotDelay);
    }

    /* ERC20 OVERRIDES */

    /// @notice Prevents transfers of the staked token.
    function transfer(address /*recipient*/, uint256 /*amount*/) public pure override(ERC20, IERC20) returns (bool) {
        revert TransfersNotAllowed();
    }

    /// @notice Prevents transfers of the staked token.
    function transferFrom(address /*sender*/, address /*recipient*/, uint256 /*amount*/) public pure override(ERC20, IERC20) returns (bool) {
        revert TransfersNotAllowed();
    }

    /* VIEW FUNCTIONS */

    /// @inheritdoc ISnapshotStakingPool
    function getCurrentSnapshotId() public view returns (uint256) {
        return _getCurrentSnapshotId();
    }

    /// @inheritdoc ISnapshotStakingPool
    function getPendingRewards(address account) public view returns (uint256) {
        uint256 currentId = _getCurrentSnapshotId();
        uint256 lastId = nextClaimId[account];
        return rewardOfInRange(account, lastId, currentId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function rewardOfInRange(address account, uint256 startSnapshotId, uint256 endSnapshotId) public view returns (uint256) {
        if (startSnapshotId == 0) revert InvalidSnapshotId();
        if (startSnapshotId > endSnapshotId || endSnapshotId > _getCurrentSnapshotId()) revert NonExistentSnapshotId();

        uint256 rewards = 0;
        for (uint256 i = startSnapshotId; i <= endSnapshotId; i++) {
            rewards += _rewardOfAt(account, i);
        }
        return rewards;
    }

    /// @inheritdoc ISnapshotStakingPool
    function rewardOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        if (snapshotId == 0) revert InvalidSnapshotId();
        if (snapshotId > _getCurrentSnapshotId()) revert NonExistentSnapshotId();
        return _rewardOfAt(account, snapshotId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function rewardAt(uint256 snapshotId) public view virtual returns (uint256) {
        if (snapshotId == 0) revert InvalidSnapshotId();
        if (snapshotId > _getCurrentSnapshotId()) revert NonExistentSnapshotId();
        return _rewardAt(snapshotId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function getRewardSnapshots() external view returns(uint256[] memory) {
        return rewardSnapshots;
    }

    /// @inheritdoc ISnapshotStakingPool
    function getLifetimeRewards(address account) public view returns (uint256) {
        return rewardOfInRange(account, 1, _getCurrentSnapshotId());
    }

    /// @inheritdoc ISnapshotStakingPool
    function canAccrue() public view returns (bool) {
        return block.timestamp >= getNextSnapshotTime();
    }

    /// @inheritdoc ISnapshotStakingPool
    function getTimeUntilNextSnapshot() public view returns (uint256) {
        if (canAccrue()) {
            return 0;
        }
        return getNextSnapshotTime() - block.timestamp;
    }

    /// @inheritdoc ISnapshotStakingPool
    function getNextSnapshotTime() public view returns (uint256) {
        return lastSnapshotTime + snapshotDelay;
    }

    /// @inheritdoc ISnapshotStakingPool
    function canStake() public view returns (bool) {
        return block.timestamp < getNextSnapshotBufferTime();
    }

    /// @inheritdoc ISnapshotStakingPool
    function getTimeUntilNextSnapshotBuffer() public view returns (uint256) {
        if (!canStake()) {
            return 0;
        }
        return getNextSnapshotBufferTime() - block.timestamp;
    }

    /// @inheritdoc ISnapshotStakingPool
    function getNextSnapshotBufferTime() public view returns (uint256) {
        return lastSnapshotTime + snapshotDelay - snapshotBuffer;
    }

    /* INTERNAL FUNCTIONS */

    function _stake(address account, uint256 amount) internal {
        if (!canStake()) revert CannotStakeDuringBuffer();
        if (nextClaimId[account] == 0) {
            uint256 currentId = _getCurrentSnapshotId();
            nextClaimId[account] = currentId > 0 ? currentId : 1;
        }
        stakeToken.transferFrom(account, address(this), amount);
        super._mint(msg.sender, amount);
    }

    function _claim(address account, uint256 startSnapshotId, uint256 endSnapshotId) internal {
        uint256 amount = rewardOfInRange(account, startSnapshotId, endSnapshotId);
        nextClaimId[account] = endSnapshotId + 1;
        rewardToken.transfer(account, amount);
    }

    function _rewardAt(uint256 snapshotId) internal view returns (uint256) {
        return rewardSnapshots[snapshotId - 1];
    }

    function _rewardOfAt(address account, uint256 snapshotId) internal view returns (uint256) {
        return _rewardAt(snapshotId) * balanceOfAt(account, snapshotId) / totalSupplyAt(snapshotId);
    }
}
