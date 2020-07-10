// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {ITimeLockRegistry} from "./ITimeLockRegistry.sol";

contract TimeLockRegistry is ITimeLockRegistry {
    struct SaftDistribution {
        uint256 value;
        address recipient;
    }

    SaftDistribution[] distributions;
    // TODO set to total SAFT accounts count
    uint256 constant COUNT = 1;

    constructor() public {
        SaftDistribution[COUNT] memory _distributions = [
            // TODO fill array with SAFT distribution addresses and values
            SaftDistribution(trustTokens(0), address(0))
        ];
        for (uint256 i = 0; i < _distributions.length; i++) {
            distributions.push(_distributions[i]);
        }
    }

    function count() external override returns (uint256) {
        return COUNT;
    }

    function getDistribution(uint256 index) external override returns (uint256, address) {
        return (distributions[index].value, distributions[index].recipient);
    }

    function trustTokens(uint256 value) internal pure returns (uint256) {
        return value * 10**8;
    }
}
