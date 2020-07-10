// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

interface ITimeLockRegistry {
    function getDistribution(uint256 index) external returns (uint256, address);

    function count() external returns (uint256);
}
