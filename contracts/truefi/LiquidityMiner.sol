// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

abstract contract LiquidityMiner {
    using SafeMath for uint256;

    struct Reward {
        uint256 amount;
        uint256 lastUpdateDistribution;
    }

    uint256 public cumulatedRewardPerToken;
    uint256 public lastUpdateBlock;
    uint256 public startingBlock;
    uint256 public constant PRECISION = 1e33;
    uint256 public constant TOTAL_BLOCKS = 1e7;
    mapping(address => Reward) rewards;

    constructor(uint256 _startingBlock) public {
        startingBlock = _startingBlock;
        lastUpdateBlock = startingBlock;
        cumulatedRewardPerToken = 0;
    }

    function squareSumTimes6(uint256 n) internal pure returns (uint256) {
        return n.mul(n.add(1)).mul(n.mul(2).add(1));
    }

    function rewardForInterval(uint256 from, uint256 to) internal pure returns (uint256) {
        return squareSumTimes6(TOTAL_BLOCKS.sub(from)).sub(squareSumTimes6(TOTAL_BLOCKS.sub(to))).mul(26824995976250469437449703116);
    }

    function updateRewardDistribution(uint256 totalPoolSupply) internal {
        uint256 currentBlock = block.number;
        if (currentBlock <= lastUpdateBlock) {
            return;
        }
        if (currentBlock > TOTAL_BLOCKS.add(startingBlock)) {
            currentBlock = TOTAL_BLOCKS.add(startingBlock);
        }
        if (totalPoolSupply != 0) {
            uint256 rewardToDistribute = rewardForInterval(lastUpdateBlock.sub(startingBlock), currentBlock.sub(startingBlock));
            cumulatedRewardPerToken = cumulatedRewardPerToken.add(rewardToDistribute.div(totalPoolSupply));
        }
        lastUpdateBlock = currentBlock;
    }

    function getReward(address account) public view returns (uint256) {
        return rewards[account].amount;
    }

    function claim() external virtual;

    function updateRewards(address account) public virtual;
}
