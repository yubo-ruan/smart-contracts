// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {TrueCurvePool, ICurvePool, IERC20} from "../TrueCurvePool.sol";

contract TrueCurvePoolUnderTest is TrueCurvePool {
    constructor(
        ICurvePool _curve,
        IERC20 token,
        IERC20 tru,
        uint256 startingBlock
    ) public TrueCurvePool(_curve, token, tru, startingBlock) {}

    function testRewardForInterval(uint256 from, uint256 to) public pure returns (uint256) {
        return rewardForInterval(from, to);
    }

    function testUpdateRewardDistribution(uint256 totalPoolSupply) public {
        updateRewardDistribution(totalPoolSupply);
    }
}
