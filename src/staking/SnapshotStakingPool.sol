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

    /* EVENTS */

    event DistributorChanged(address newDistributor);
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
    uint256 public snapshotDelay;
    /// @inheritdoc ISnapshotStakingPool
    uint256 public lastSnapshotTime;

    /* CONSTRUCTOR */

    /// @param _name Name of the staked token
    /// @param _symbol Symbol of the staked token
    /// @param _rewardToken Instance of the reward token
    /// @param _stakeToken Instance of the stake token
    /// @param _distributor Address of the distributor
    /// @param _snapshotDelay The minimum amount of time between snapshots
    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        IERC20 _stakeToken,
        address _distributor,
        uint256 _snapshotDelay
    )
        ERC20(_name, _symbol)
    {
        rewardToken = _rewardToken;
        stakeToken = _stakeToken;
        distributor = _distributor;
        snapshotDelay = _snapshotDelay;
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the distributor.
    modifier onlyDistributor() {
        require(msg.sender == distributor, "Must be distributor");
        _;
    }

    /* STAKER FUNCTIONS */

    /// @inheritdoc ISnapshotStakingPool
    function stake(uint256 amount) external virtual nonReentrant {
        _stake(msg.sender, amount);
    }

    /// @inheritdoc ISnapshotStakingPool
    function unstake(uint256 amount) public nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        super._burn(msg.sender, amount);
        stakeToken.transfer(msg.sender, amount);
    }

    /// @inheritdoc ISnapshotStakingPool
    function accrue(uint256 amount) external nonReentrant onlyDistributor {
        require(amount > 0, "Cannot accrue 0");
        require(totalSupply() > 0, "Cannot accrue with 0 staked supply");
        require(canAccrue(), "Snapshot delay not passed");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        lastSnapshotTime = block.timestamp;
        rewardSnapshots.push(amount);
        super._snapshot();
    }

    /// @inheritdoc ISnapshotStakingPool
    function claim() public nonReentrant {
        uint256 currentId = _getCurrentSnapshotId();
        uint256 lastId = nextClaimId[msg.sender];
        uint256 amount = rewardOfInRange(msg.sender, lastId, currentId);
        require(amount > 0, "No rewards to claim");
        nextClaimId[msg.sender] = currentId + 1;
        rewardToken.transfer(msg.sender, amount);
    }

    /// @inheritdoc ISnapshotStakingPool
    function claimPartial(uint256 startSnapshotId, uint256 endSnapshotId) public nonReentrant {
        require(startSnapshotId >= nextClaimId[msg.sender], "Cannot claim from past snapshots");
        uint256 amount = rewardOfInRange(msg.sender, startSnapshotId, endSnapshotId);
        require(amount > 0, "No rewards to claim");
        nextClaimId[msg.sender] = endSnapshotId + 1;
        rewardToken.transfer(msg.sender, amount);
    }

    /* ADMIN FUNCTIONS */

    /// @inheritdoc ISnapshotStakingPool
    function setDistributor(address newDistributor) external onlyOwner {
        distributor = newDistributor;
        emit DistributorChanged(newDistributor);
    }

    /// @inheritdoc ISnapshotStakingPool
    function setSnapshotDelay(uint256 newSnapshotDelay) external onlyOwner {
        snapshotDelay = newSnapshotDelay;
        emit SnapshotDelayChanged(newSnapshotDelay);
    }

    /* ERC20 OVERRIDES */

    /// @notice Prevents transfers of the staked token.
    function transfer(address /*recipient*/, uint256 /*amount*/) public pure override(ERC20, IERC20) returns (bool) {
        revert("Transfers not allowed");
    }

    /// @notice Prevents transfers of the staked token.
    function transferFrom(address /*sender*/, address /*recipient*/, uint256 /*amount*/) public pure override(ERC20, IERC20) returns (bool) {
        revert("Transfers not allowed");
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
        require(startSnapshotId > 0, "ERC20Snapshot: id is 0");
        require(startSnapshotId <= endSnapshotId && endSnapshotId <= _getCurrentSnapshotId(), "ERC20Snapshot: nonexistent id");

        uint256 rewards = 0;
        for (uint256 i = startSnapshotId; i <= endSnapshotId; i++) {
            rewards += _rewardOfAt(account, i);
        }
        return rewards;
    }

    /// @inheritdoc ISnapshotStakingPool
    function rewardOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        require(snapshotId > 0, "ERC20Snapshot: id is 0");
        require(snapshotId <= _getCurrentSnapshotId(), "ERC20Snapshot: nonexistent id");
        return _rewardOfAt(account, snapshotId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function rewardAt(uint256 snapshotId) public view virtual returns (uint256) {
        require(snapshotId > 0, "ERC20Snapshot: id is 0");
        require(snapshotId <= _getCurrentSnapshotId(), "ERC20Snapshot: nonexistent id");
        return _rewardAt(snapshotId);
    }

    /// @inheritdoc ISnapshotStakingPool
    function getRewardSnapshots() external view returns(uint256[] memory) {
        return rewardSnapshots;
    }

    /// @inheritdoc ISnapshotStakingPool
    function canAccrue() public view returns (bool) {
        return block.timestamp >= lastSnapshotTime + snapshotDelay;
    }

    /// @inheritdoc ISnapshotStakingPool
    function getTimeUntilNextSnapshot() public view returns (uint256) {
        if (canAccrue()) {
            return 0;
        }
        return (lastSnapshotTime + snapshotDelay) - block.timestamp;
    }

    /* INTERNAL FUNCTIONS */

    function _stake(address account, uint256 amount) internal {
        require(amount > 0, "Cannot stake 0");
        if (nextClaimId[account] == 0) {
            uint256 currentId = _getCurrentSnapshotId();
            nextClaimId[account] = currentId > 0 ? currentId : 1;
        }
        stakeToken.transferFrom(account, address(this), amount);
        super._mint(msg.sender, amount);
    }

    function _rewardAt(uint256 snapshotId) internal view returns (uint256) {
        return rewardSnapshots[snapshotId - 1];
    }

    function _rewardOfAt(address account, uint256 snapshotId) internal view returns (uint256) {
        return _rewardAt(snapshotId) * balanceOfAt(account, snapshotId) / totalSupplyAt(snapshotId);
    }
}
