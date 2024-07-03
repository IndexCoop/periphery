// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IPrtFeeSplitExtension {
    function accrueFeesAndDistribute() external;
    function isAnyoneAllowedToAccrue() external view returns (bool);
    function prtStakingPool() external view returns (address);
    function updateAnyoneAccrue(bool _anyoneAccrue) external;
    function updateFeeRecipient(address _feeRecipient) external;
    function updatePrtStakingPool(address _prtStakingPool) external;
}
