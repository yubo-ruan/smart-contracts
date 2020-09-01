import { beforeEachWithFixture } from '../utils/beforeEachWithFixture'
import { Wallet } from 'ethers'
import { MockErc20TokenFactory } from '../../build/types/MockErc20TokenFactory'
import { MockErc20Token } from '../../build/types/MockErc20Token'
import { TrueCurvePoolUnderTestFactory } from '../../build/types/TrueCurvePoolUnderTestFactory'
import { TrueCurvePoolUnderTest } from '../../build/types/TrueCurvePoolUnderTest'
import { MockCurvePool } from '../../build/types/MockCurvePool'
import { MockCurvePoolFactory } from '../../build/types/MockCurvePoolFactory'
import { parseEther, BigNumber, parseUnits } from 'ethers/utils'
import { Erc20 } from '../../build/types/Erc20'
import { Erc20Factory } from '../../build/types/Erc20Factory'
import { expect } from 'chai'
import { MockProvider } from 'ethereum-waffle'
import { Zero, MaxUint256 } from 'ethers/constants'
import { toTrustToken } from '../../scripts/utils/toTrustToken'

describe('Curve Pool', () => {
  let owner: Wallet
  let acc1: Wallet
  let acc2: Wallet
  let acc3: Wallet
  let token: MockErc20Token
  let cTUSD: Erc20
  let curve: MockCurvePool
  let pool: TrueCurvePoolUnderTest
  let startingBlock: number
  let provider: MockProvider

  beforeEachWithFixture(async (_provider, wallets) => {
    [owner, acc1, acc2, acc3] = wallets
    provider = _provider
    token = await new MockErc20TokenFactory(owner).deploy()
    await token.mint(owner.address, parseEther('1'))
    curve = await new MockCurvePoolFactory(owner).deploy(token.address)
    cTUSD = Erc20Factory.connect(await curve.token(), owner)
    startingBlock = await provider.getBlockNumber() + 5
    pool = await new TrueCurvePoolUnderTestFactory(owner).deploy(curve.address, token.address, startingBlock)
  })

  const unPrecise = (amount: BigNumber) => amount.div(parseUnits('1', 33))

  async function join(who: Wallet, amount: BigNumber) {
    await token.connect(who).approve(pool.address, amount)
    const joinTx = await pool.connect(who).join(amount)
    return (await provider.getTransaction(joinTx.hash)).blockNumber
  }

  async function exit(who: Wallet, amount: BigNumber) {
    const exitTx = await pool.connect(who).exit(amount)
    return (await provider.getTransaction(exitTx.hash)).blockNumber
  }

  describe('joining', () => {
    it('correctly transfers tokens', async () => {
      await join(owner, parseEther('1'))
      expect(await pool.balanceOf(owner.address)).to.equal(parseEther('1'))
      expect(await cTUSD.balanceOf(pool.address)).to.equal(parseEther('1'))
      expect(await token.balanceOf(curve.address)).to.equal(parseEther('1'))
    })

    it('minimal token amount on equals 99% of curve estimation', async () => {
      await join(owner, parseEther('1'))
      expect('add_liquidity').to.be.calledOnContractWith(curve, [[0, 0, 0, parseEther('1')], parseEther('0.99')])
    })
  })

  describe('exiting', () => {
    beforeEach(async () => {
      await join(owner, parseEther('1'))
    })

    it('correctly transfers tokens', async () => {
      await exit(owner, parseEther('1'))
      expect(await pool.balanceOf(owner.address)).to.equal(0)
      expect(await pool.totalSupply()).to.equal(0)
      expect(await cTUSD.totalSupply()).to.equal(0)
      expect(await token.balanceOf(owner.address)).to.equal(parseEther('1'))
    })

    it('minimal token amount on withdrawal equals 99% of curve estimation', async () => {
      await exit(owner, parseEther('1'))
      expect('remove_liquidity_one_coin').to.be.calledOnContractWith(curve, [parseEther('1'), 3, parseEther('0.99')])
    })
  })

  describe('rewardForInterval', () => {
    it('returns 0 for 0 blocks interval', async () => {
      expect(await pool.testRewardForInterval(0, 0)).to.equal(0)
      expect(await pool.testRewardForInterval(10, 10)).to.equal(0)
      expect(await pool.testRewardForInterval(1000, 1000)).to.equal(0)
    })

    it('has correct precision', async () => {
      expect((await pool.testRewardForInterval(0, await pool.TOTAL_BLOCKS())).div(await pool.PRECISION())).to.equal(toTrustToken(536500000).sub(1))
    })

    it('from block 0 to last', async () => {
      expect(await pool.testRewardForInterval(0, await pool.TOTAL_BLOCKS())).to.equal('53649999999999999999999999971605309297031160000000')
    })

    it('sums to total TRU pool with step 100000', async () => {
      let sum = Zero
      let lastReward = MaxUint256
      const totalBlocks = await pool.TOTAL_BLOCKS()

      for (let i = 0; i < totalBlocks; i += 100000) {
        const newReward = await pool.testRewardForInterval(i, Math.min(i + 100000, totalBlocks))
        expect(newReward).to.be.lt(lastReward)
        sum = sum.add(newReward)
        lastReward = newReward
      }
      expect(sum).to.equal('53649999999999999999999999971605309297031160000000')
    })
  })

  describe('updateRewardDistribution', () => {
    it('does not update anything before startBlock', async () => {
      const initialCumulatedRewardPerToken = await pool.cumulatedRewardPerToken()
      const initialLastUpdateBlock = await pool.lastUpdateBlock()

      await pool.testUpdateRewardDistribution(parseEther('1'))

      expect(await pool.cumulatedRewardPerToken()).to.equal(initialCumulatedRewardPerToken)
      expect(await pool.lastUpdateBlock()).to.equal(initialLastUpdateBlock)
    })

    it('updates lastUpdateBlock and cumulatedRewardPerToken with 10^18 precision accordingly (one block)', async () => {
      while (await provider.getBlockNumber() !== startingBlock) {
        await provider.send('evm_mine', [])
      }
      const initialCumulatedRewardPerToken = await pool.cumulatedRewardPerToken()

      const reward = await pool.testRewardForInterval(0, 1)
      await pool.testUpdateRewardDistribution(parseEther('5'))

      expect(await pool.cumulatedRewardPerToken()).to.equal(initialCumulatedRewardPerToken.add(reward.div(parseEther('5'))))
      expect(await pool.lastUpdateBlock()).to.equal(startingBlock + 1)
    })

    it('updates lastUpdateBlock and cumulatedRewardPerToken with 10^18 precision accordingly (many blocks)', async () => {
      while (await provider.getBlockNumber() !== startingBlock + 2) {
        await provider.send('evm_mine', [])
      }
      const reward = await pool.testRewardForInterval(0, 3)
      const initialCumulatedRewardPerToken = await pool.cumulatedRewardPerToken()

      await pool.testUpdateRewardDistribution(parseEther('5'))

      expect(await pool.cumulatedRewardPerToken()).to.equal(initialCumulatedRewardPerToken.add(reward.div(parseEther('5'))))
      expect(await pool.lastUpdateBlock()).to.equal(startingBlock + 3)
    })
  })

  describe('updateRewards', () => {
    beforeEach(async () => {
      await token.mint(acc1.address, parseEther('1'))
      await token.mint(acc2.address, parseEther('1'))
      await token.mint(acc3.address, parseEther('1'))
      while (await provider.getBlockNumber() !== startingBlock + 10) {
        await provider.send('evm_mine', [])
      }
    })

    it('properly distributes reward to a single participant', async () => {
      const joinBlockNumber = await join(owner, parseEther('1'))

      const updateTx = await pool.updateRewards(owner.address)
      const updateBlockNumber = (await provider.getTransaction(updateTx.hash)).blockNumber

      const expectedReward = await pool.testRewardForInterval(joinBlockNumber - startingBlock, updateBlockNumber - startingBlock)

      expect(await pool.getReward(owner.address)).to.equal(unPrecise(expectedReward))
    })

    it.only('properly distributes reward to a multiple participants', async () => {
      const join1BlockNumber = await join(acc1, parseEther('1'))
      const join2BlockNumber = await join(acc2, parseEther('1'))
      // const join3BlockNumber = await join(acc3, parseEther('1'))

      // const exit3BlockNumber = await exit(acc3, parseEther('1'))
      // const exit2BlockNumber = await exit(acc2, parseEther('1'))
      const exit1BlockNumber = await exit(acc1, parseEther('1'))
      console.log(join1BlockNumber, join2BlockNumber, exit1BlockNumber)
      let blockRewards: BigNumber[] = []
      for (let i = join1BlockNumber; i < exit1BlockNumber; i++) {
        blockRewards.push(unPrecise(await pool.testRewardForInterval(i - startingBlock, i + 1 - startingBlock)))
      }
      const expectedReward1 = blockRewards[0]
        .add(blockRewards[1])
        .add(blockRewards[2])
      // .add(blockRewards[1].div(2))
      // .add(blockRewards[2].div(3))
      // .add(blockRewards[3].div(3))
      // .add(blockRewards[4].div(2))
      // .add(blockRewards[5])
      expect(await pool.getReward(acc1.address)).to.equal(expectedReward1)
      // const expectedRewardInBlock1 = await pool.testRewardForInterval(bn - 2, bn - 1)
      // const expectedRewardInBlock2 = await pool.testRewardForInterval(bn, bn + 1)
      // const expectedRewardInBlock3 = await pool.testRewardForInterval(bn - 1, bn + 1)
    })
  })
})

// #1: 1-100% 2-0% 3-0%
// #2: 1-50% 2-50% 3-0%
// #3: 1-33% 2-33% 3-33%
// #4: 1-33% 2-33% 3-33%
// #5: 1-50% 2-50% 3-0%
// #6: 1-100% 2-0% 3-0%