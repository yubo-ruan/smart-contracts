import { contract, createProxy, deploy, Future } from 'ethereum-mars'
import {
  LinearTrueDistributor,
  LoanFactory, MockCurvePool,
  OwnedUpgradeabilityProxy,
  TrueFiPool, TrueLender,
  TrueRatingAgency, MockERC20Token,
  MockCurveGauge, LoanToken,
} from '../build/artifacts'
import config from './config.json'
import { constants, utils } from 'ethers'
import { makeContractInstance } from 'ethereum-mars/build/src/syntax/contract'

const { contracts: { uniswapRouter }, distributionStart } = config.mainnet

const month = 60 * 60 * 24 * 30

deploy({}, () => {
  const proxy = createProxy(OwnedUpgradeabilityProxy)
  const mockTUsd = contract('tusd', MockERC20Token)
  const mockTrustToken = contract('trustToken', MockERC20Token)
  const mockYCRV = contract('ycrv', MockERC20Token)
  const mockCRV = contract('crv', MockERC20Token)

  const loanFactory = proxy(contract(LoanFactory), 'initialize', [mockTUsd])
  const votersDistributor = proxy(contract('TRU Voters Distributor', LinearTrueDistributor), 'initialize', [
    distributionStart, 48 * month, utils.parseUnits('254475000', 8), mockTrustToken,
  ])
  const mockCurve = proxy(contract(MockCurvePool), 'initialize', [mockYCRV])
  const mockGauge = contract(MockCurveGauge, [mockCRV])

  const trueRatingAgency = proxy(contract(TrueRatingAgency), 'initialize', [mockTrustToken, votersDistributor, loanFactory])
  const trueLender = proxy(contract(TrueLender), () => {})
  const trueFiPool = proxy(contract(TrueFiPool), 'initialize', [mockCurve, mockGauge, mockTUsd, trueLender, uniswapRouter])

  trueLender.initialize(trueFiPool, trueRatingAgency)

  // loanFactory.createLoanToken(constants.AddressZero, 100, 100, 100)
})
