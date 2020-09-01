// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import {TrueFiPool, IERC20} from "./TrueFiPool.sol";
import {LiquidityMiner} from "./LiquidityMiner.sol";
import {ICurvePool} from "./ICurvePool.sol";

contract TrueCurvePool is TrueFiPool, LiquidityMiner {
    ICurvePool public curvePool;
    IERC20 tru;
    uint8 constant N_TOKENS = 4;
    uint8 constant TUSD_INDEX = 3;

    constructor(
        ICurvePool _curve,
        IERC20 token,
        IERC20 _tru,
        uint256 startingBlock
    ) public TrueFiPool(token, "TrueCurvePool", "TCP") LiquidityMiner(startingBlock) {
        curvePool = _curve;
        tru = _tru;
        token.approve(address(curvePool), uint256(-1));
        curvePool.token().approve(address(curvePool), uint256(-1));
    }

    function join(uint256 amount) external override {
        updateRewards(msg.sender);
        require(token.transferFrom(msg.sender, address(this), amount));

        uint256[N_TOKENS] memory amounts = [0, 0, 0, amount];
        uint256 minTokenAmount = curvePool.curve().calc_token_amount(amounts, true).mul(99).div(100);

        uint256 balanceBefore = curvePool.token().balanceOf(address(this));
        curvePool.add_liquidity(amounts, minTokenAmount);
        uint256 balanceAfter = curvePool.token().balanceOf(address(this));
        _mint(msg.sender, balanceAfter.sub(balanceBefore));
    }

    function exit(uint256 amount) external override {
        updateRewards(msg.sender);
        require(amount <= balanceOf(msg.sender), "Insufficient balance");

        uint256 minTokenAmount = curvePool.calc_withdraw_one_coin(amount, TUSD_INDEX).mul(99).div(100);

        uint256 balanceBefore = token.balanceOf(address(this));
        curvePool.remove_liquidity_one_coin(amount, TUSD_INDEX, minTokenAmount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balanceAfter.sub(balanceBefore)));
        _burn(msg.sender, amount);
    }

    function value() external override view returns (uint256) {
        return curvePool.calc_withdraw_one_coin(1 ether, TUSD_INDEX);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        updateRewards(sender);
        updateRewards(recipient);
        super._transfer(sender, recipient, amount);
    }

    function updateRewards(address account) public override {
        updateRewardDistribution(totalSupply());
        Reward storage reward = rewards[account];
        reward.amount = reward.amount.add(
            balanceOf(account).mul(cumulatedRewardPerToken.sub(reward.lastUpdateDistribution)).div(PRECISION)
        );
        reward.lastUpdateDistribution = cumulatedRewardPerToken;
    }

    function claim() external override {
        updateRewards(msg.sender);
        require(tru.transfer(msg.sender, getReward(msg.sender)));
    }
}
