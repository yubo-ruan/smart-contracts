// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TrueDistributor
 * @notice Distributes TRU to TrueFarm farms
 * @dev This contract distributes tokens starting from `startingBlock` for the next 10 million block (roughly 4.5 years)
 * The tokens will be distributed according to the declining quadratic curve
 * For each block `DISTRIBUTION_FACTOR*(10M-n)^2` TRU is awarded where `n` is a block number since `startingBlock`
 * `DISTRIBUTION_FACTOR` has been selected so that 536,500,000 (39% of total TRU supply) will be awarded in total
 */
contract TrueDistributor is Ownable {
    using SafeMath for uint256;

    struct Farm {
        uint256 shares;
        uint256 reward;
        uint256 lastRewardBlock;
        uint256 lastDistributionEpoch;
    }

    uint256 public constant DISTRIBUTION_FACTOR = 26824995976250469437449703116;
    uint256 public constant TOTAL_BLOCKS = 1e7;
    uint256 public constant PRECISION = 1e33;
    uint256 public constant TOTAL_SHARES = 1e7;
    uint256 public constant EPOCH_LENGTH = 5;
    ERC20 public token;
    uint256 public startingBlock;
    mapping(address => Farm) public farms;

    constructor(uint256 _startingBlock, ERC20 _token) public {
        startingBlock = _startingBlock;
        token = _token;
        farms[msg.sender].shares = TOTAL_SHARES;
    }

    /**
     * @notice transfer all rewards since previous `distribute` call to the `farm`.
     * Transferred reward is proportional to the stake of the farm
     */
    function distribute() external returns (uint256) {
        address farm = msg.sender;
        uint256 farmsReward = saveReward(farm);

        if (currentEpoch() > farms[farm].lastDistributionEpoch) {
            require(token.transfer(farm, farms[farm].reward));
            farms[farm].reward = 0;
            farms[farm].lastDistributionEpoch = currentEpoch();
        }

        return farmsReward;
    }

    function saveReward(address farm) internal returns (uint256) {
        uint256 currentBlock = block.number;
        uint256 totalRewardForInterval = reward(farms[farm].lastRewardBlock, currentBlock);

        farms[farm].lastRewardBlock = currentBlock;

        uint256 farmsReward = totalRewardForInterval.mul(farms[farm].shares).div(TOTAL_SHARES);
        farms[farm].reward = farms[farm].reward.add(normalise(farmsReward));

        return farmsReward;
    }

    function normalise(uint256 amount) public pure returns (uint256) {
        return amount.div(PRECISION);
    }

    function transfer(
        address fromFarm,
        address toFarm,
        uint256 sharesAmount
    ) external onlyOwner {
        saveReward(fromFarm);
        saveReward(toFarm);
        farms[fromFarm].shares = farms[fromFarm].shares.sub(sharesAmount);
        farms[toFarm].shares = farms[toFarm].shares.add(sharesAmount);
    }

    function getShares(address farm) external view returns (uint256) {
        return farms[farm].shares;
    }

    function getLastDistributionBlock(address farm) external view returns (uint256) {
        return farms[farm].lastRewardBlock;
    }

    /**
     * @notice Reward from `fromBlock` to `toBlock`.
     */
    function reward(uint256 fromBlock, uint256 toBlock) public view returns (uint256) {
        require(fromBlock <= toBlock, "invalid interval");
        if (toBlock < startingBlock || fromBlock > TOTAL_BLOCKS || fromBlock == toBlock) {
            return 0;
        }
        if (fromBlock < startingBlock) {
            fromBlock = startingBlock;
        }
        if (toBlock > TOTAL_BLOCKS) {
            toBlock = TOTAL_BLOCKS;
        }
        return rewardFormula(fromBlock.sub(startingBlock), toBlock.sub(startingBlock));
    }

    /**
     * @dev Calculates sum of rewards from `fromBlock` to `toBlock`.
     * Uses the fact that sum of n first squares is calculated by n(n+1)(2n+1)/6
     */
    function rewardFormula(uint256 fromBlock, uint256 toBlock) internal virtual pure returns (uint256) {
        return squareSumTimes6(TOTAL_BLOCKS.sub(fromBlock)).sub(squareSumTimes6(TOTAL_BLOCKS.sub(toBlock))).mul(DISTRIBUTION_FACTOR);
    }

    function squareSumTimes6(uint256 n) internal pure returns (uint256) {
        return n.mul(n.add(1)).mul(n.mul(2).add(1));
    }

    function currentEpoch() public view returns (uint256) {
        if (block.number < startingBlock) {
            return 0;
        }
        return block.number.sub(startingBlock).div(epochLength());
    }

    function nextEpoch() external view returns (uint256) {
        return startingBlock.add(epochLength().mul(currentEpoch().add(1)));
    }

    function epochLength() internal virtual pure returns (uint256) {
        return EPOCH_LENGTH;
    }
}
