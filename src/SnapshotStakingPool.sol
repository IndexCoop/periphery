// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Snapshot } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SnapshotStakingPool
 * @author Index Cooperative
 * @dev A contract for staking `stakeToken` and receiving `rewardToken` based 
 * on snapshots taken when rewards are accrued. The contract requires a 
 * StakeMessage to be signed by the staker to stake tokens.
 */
contract SnapshotStakingPool is Ownable, ERC20Snapshot, EIP712, ReentrancyGuard {
    string private constant MESSAGE_TYPE = "StakeMessage(uint256 nonce, uint256 deadline, uint256 amount)";

    /* ============ Events ============ */

    event DistributorChanged(address _newDistributor);
    event SnapshotDelayChanged(uint256 _newSnapshotDelay);

    /* ============ Immutables ============ */

    IERC20 public immutable rewardToken;  // Token to be distributed as rewards
    IERC20 public immutable stakeToken;   // Token to be staked

    /* ============ State Variables ============ */

    address public distributor;     // Distributor of rewards

    mapping(address => uint256) public stakeNonce;      // Nonce of last stake action to avoid replay attack
    mapping(address => uint256) public lastSnapshotId;  // Snapshot ID of the last claim for each staker
    uint256[] public accrueSnapshots;                   // Amount of rewards accrued with each snapshot

    uint256 public snapshotDelay;         // The minimum amount of time between snapshots
    uint256 public lastSnapshotTime;      // The last time a snapshot was taken

    /* ============ Modifiers ============ */

    modifier onlyDistributor() {
        require(msg.sender == distributor, "Must be distributor");
        _;
    }

    /* ========== Constructor ========== */

    /**
     * @notice Constructor to initialize the Snapshot Staking Pool.
     * @param _eip712Name Name of the EIP712 signing domain
     * @param _eip712Version Current major version of the EIP712 signing domain
     * @param _name Name of the staked token
     * @param _symbol Symbol of the staked token
     * @param _rewardToken Instance of the reward token
     * @param _stakeToken Instance of the stake token
     * @param _distributor Address of the distributor
     * @param _snapshotDelay The minimum amount of time between snapshots
     */
    constructor(
        string memory _eip712Name,
        string memory _eip712Version,
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        IERC20 _stakeToken,
        address _distributor,
        uint256 _snapshotDelay
    )
        EIP712(_eip712Name, _eip712Version)
        ERC20(_name, _symbol)
    {
        rewardToken = _rewardToken;
        stakeToken = _stakeToken;
        distributor = _distributor;
        snapshotDelay = _snapshotDelay;
    }

    /* ========== External Functions ========== */

    /**
     * @notice Stake `amount` of stakeToken from `msg.sender` and mint staked tokens.
     * @param _amount The amount of stakeToken to stake
     */
    function stake(uint256 _amount, bytes memory _signature, address _staker, uint256 _deadline) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        require(_deadline >= block.timestamp, "Deadline passed");
        require(verifyStakeSignature(_signature, _staker, _deadline, _amount), "Invalid signature"); 
        stakeToken.transferFrom(_staker, address(this), _amount);
        stakeNonce[_staker]++;
        super._mint(_staker, _amount);
    }

    /**
     * @notice Unstake `amount` of stakeToken by `msg.sender`.
     * @param _amount The amount of stakeToken to unstake
     */
    function unstake(uint256 _amount) public nonReentrant {
        require(_amount > 0, "Cannot unstake 0");
        super._burn(msg.sender, _amount);
        stakeToken.transfer(msg.sender, _amount);
    }

    /**
     * @notice ONLY DISTRIBUTOR: Accrue rewardToken and update snapshot.
     * @param _amount The amount of rewardToken to accrue
     */
    function accrue(uint256 _amount) external nonReentrant onlyDistributor {
        require(_amount > 0, "Cannot accrue 0");
        require(totalSupply() > 0, "Cannot accrue with 0 staked supply");
        require(canAccrue(), "Snapshot delay not passed");
        rewardToken.transferFrom(msg.sender, address(this), _amount);
        lastSnapshotTime = block.timestamp;
        accrueSnapshots.push(_amount);
        super._snapshot();
    }

    /**
     * @notice Claim the staking rewards from pending snapshots for `msg.sender`.
     */
    function claim() public nonReentrant {
        uint256 currentId = getCurrentId();
        uint256 amount = _getPendingRewards(currentId, msg.sender);
        require(amount > 0, "No rewards to claim");
        lastSnapshotId[msg.sender] = currentId;
        rewardToken.transfer(msg.sender, amount);
    }

    /**
     * @notice Claim partial staking rewards from pending snapshots for `msg.sender` from `_startClaimId` to `_endClaimId`.
     * @param _startClaimId The snapshot id to start the partial claim
     * @param _endClaimId The snapshot id to end the partial claim
     */
    function claimPartial(uint256 _startClaimId, uint256 _endClaimId) public nonReentrant {
        uint256 currentId = getCurrentId();
        uint256 amount = _getPendingPartialRewards(currentId, _startClaimId, _endClaimId, msg.sender);
        require(amount > 0, "No rewards to claim");
        lastSnapshotId[msg.sender] = _endClaimId;
        rewardToken.transfer(msg.sender, amount);
    }

    /**
     * @notice ONLY OWNER: Update the distributor address.
     */
    function setDistributor(address _distributor) external onlyOwner {
        distributor = _distributor;
        emit DistributorChanged(_distributor);
    }

    /**
     * @notice ONLY OWNER: Update the snapshot delay. Can set to 0 to disable snapshot delay.
     * @param _snapshotDelay The new snapshot delay
     */
    function setSnapshotDelay(uint256 _snapshotDelay) external onlyOwner {
        snapshotDelay = _snapshotDelay;
        emit SnapshotDelayChanged(_snapshotDelay);
    }

    /* ========== ERC20 Overrides ========== */

    function transfer(address /*recipient*/, uint256 /*amount*/) public pure override returns (bool) {
        revert("Transfers not allowed");
    }

    function transferFrom(address /*sender*/, address /*recipient*/, uint256 /*amount*/) public pure override returns (bool) {
        revert("Transfers not allowed");
    }

    /* ========== View Functions ========== */

    /**
     * @notice Get the signer of the StakeMessage using EIP712
     * @param _signature The signature to verify
     * @return The address of the signer
     */
    function verifyStakeSignature(bytes memory _signature, address _staker, uint256 _deadline, uint256 _amount) public view returns (bool) {
        bytes32 digest = getStakeSignatureDigest(_staker, _deadline, _amount);
        address signer = ECDSA.recover(digest, _signature);
        return(signer == _staker);
    }

    /**
     * @notice Get the hashed digest of the message to be signed for staking
     * @return The hashed bytes to be signed
     */
    function getStakeSignatureDigest(address _staker, uint256 _deadline, uint256 _amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(abi.encodePacked(MESSAGE_TYPE)),
                    stakeNonce[_staker],
                    _deadline,
                    _amount
                )
            )
        );
    }

    /**
     * @notice Check if rewards can be accrued.
     * @return Boolean indicating if rewards can be accrued
     */
    function canAccrue() public view returns (bool) {
        return block.timestamp >= lastSnapshotTime + snapshotDelay;
    }

    /**
     * @notice Get the time until the next snapshot.
     * @return The time until the next snapshot
     */
    function getTimeUntilNextSnapshot() public view returns (uint256) {
        if (canAccrue()) {
            return 0;
        }
        return (lastSnapshotTime + snapshotDelay) - block.timestamp;
    }

    /**
     * @notice Get the current snapshot id.
     * @return The current snapshot id
     */
    function getCurrentId() public view returns (uint256) {
        return accrueSnapshots.length;
    }

    /**
     * @notice Get pending rewards for an account.
     * @param _account The address of the account
     * @return The pending rewards for the account
     */
    function getPendingRewards(
        address _account
    ) external view returns (uint256) {
        uint256 currentId = getCurrentId();
        return _getPendingRewards(currentId, _account);
    }

    /**
     * @notice Get pending partial rewards for an account.
     * @param _account The address of the account
     * @param _startClaimId The snapshot id to start the partial claim
     * @param _endClaimId The snapshot id to end the partial claim
     * @return The pending partial rewards for the account
     */
    function getPendingPartialRewards(
        address _account,
        uint256 _startClaimId,
        uint256 _endClaimId
    ) external view returns (uint256) {
        uint256 currentId = getCurrentId();
        return _getPendingPartialRewards(currentId, _startClaimId, _endClaimId, _account);
    }

    /**
     * @notice Get rewards for an account from a specific snapshot id.
     * @param _snapshotId The snapshot id
     * @param _account The address of the account
     * @return The rewards for the account from the snapshot id
     */
    function getSnapshotRewards(
        uint256 _snapshotId,
        address _account
    ) external view returns (uint256) {
        return _getSnapshotRewards(_snapshotId, _account);
    }

    /**
     * @notice Get account summary for a specific snapshot id.
     * @param _snapshotId The snapshot id
     * @param _account The address of the account
     * @return snapshotRewards The rewards for the account from the snapshot id
     * @return totalRewards The total rewards accrued from the snapshot id
     * @return totalSupply The total staked supply at the snapshot id
     * @return balance The staked balance of the account at the snapshot id
     */
    function getSnapshotSummary(
        uint256 _snapshotId,
        address _account
    ) 
        external 
        view 
        returns (
            uint256 snapshotRewards, 
            uint256 totalRewards, 
            uint256 totalSupply, 
            uint256 balance
        ) 
    {
        uint256 internalId = _snapshotId + 1;
        snapshotRewards = _getSnapshotRewards(_snapshotId, _account);
        totalRewards = accrueSnapshots[_snapshotId];
        totalSupply = totalSupplyAt(internalId);
        balance = balanceOfAt(_account, internalId);
    }

    /**
     * @notice Get accrue snapshots.
     * @return The accrue snapshots
     */
    function getAccrueSnapshots() external view returns(uint256[] memory) {
        return accrueSnapshots;
    }

    /* ========== Internal Functions ========== */

    /**
     * @dev Get pending rewards for an account.
     * @param _currentId The current snapshot id
     * @param _account The address of the account
     * @return amount The pending rewards for the account
     */
    function _getPendingRewards(
        uint256 _currentId,
        address _account
    ) 
        private 
        view 
        returns (uint256 amount) 
    {
        uint256 lastRewardId = lastSnapshotId[_account];
        for (uint256 i = lastRewardId; i < _currentId; i++) {
            amount += _getSnapshotRewards(i, _account);
        }
    }

    /**
     * @dev Get pending partial rewards for an account.
     * @param _currentId The current snapshot id
     * @param _startClaimId The snapshot id to start the partial claim
     * @param _endClaimId The snapshot id to end the partial claim
     * @param _account The address of the account
     * @return amount The pending partial rewards for the account
     */
    function _getPendingPartialRewards(
        uint256 _currentId,
        uint256 _startClaimId,
        uint256 _endClaimId,
        address _account
    ) 
        private 
        view 
        returns (uint256 amount) 
    {
        require(_startClaimId >= lastSnapshotId[_account], "Start claim id must be greater than last snapshot id");
        require(_endClaimId <= _currentId, "End claim id must be less than current snapshot id");
        for (uint256 i = _startClaimId; i < _endClaimId; i++) {
            amount += _getSnapshotRewards(i, _account);
        }
    }

    /**
     * @dev Get rewards for an account from a specific snapshot id.
     * @param _snapshotId The snapshot id
     * @param _account The address of the account
     * @return The rewards for the account from the snapshot id
     */
    function _getSnapshotRewards(
        uint256 _snapshotId,
        address _account
    ) 
        private 
        view 
        returns (uint256) 
    {
        uint256 internalId = _snapshotId + 1;
        return (accrueSnapshots[_snapshotId] * balanceOfAt(_account, internalId)) / totalSupplyAt(internalId);
    }
}
