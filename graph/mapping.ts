import { LoanTokenCreated } from './generated/LoanFactory/LoanFactory'
import { LoanToken as LoanTokenContract } from './generated/LoanFactory/LoanToken'
import { LoanToken } from './generated/schema'
import { log } from '@graphprotocol/graph-ts'

export function handleNewToken (event: LoanTokenCreated): void {
  log.info('HANDLENEWTOKEN {}', [event.params.contractAddress.toHexString()])
  const address = event.params.contractAddress
  const loanToken = new LoanToken(address.toHexString())
  loanToken.address = address
  const tokenContract = LoanTokenContract.bind(address)
  // throws here
  log.info('AAAAAAAAA', [])
  tokenContract.apy()
  log.info('BBBBBBBB', [])
  loanToken.apy = tokenContract.apy()
  loanToken.amount = tokenContract.amount()
  loanToken.term = tokenContract.term()
  loanToken.debt = tokenContract.debt()
  loanToken.borrower = tokenContract.borrower()
  loanToken.save()
}
