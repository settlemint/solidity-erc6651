import {
  Address,
  BigInt,
} from '@graphprotocol/graph-ts'

import {
  Account,
  ERC6551BatchContract,
} from '../../generated/schema'

import {
  fetchAccount
} from './account'

export function fetchERC6551Batch(address: Address): ERC6551BatchContract | null {
  let id = address

  // Try load entry
  let contract = ERC6551BatchContract.load(id)
  if (contract != null) {
    return contract
  }

  // Create new entry
  contract = new ERC6551BatchContract(id)
  contract.asAccount = address
  contract.totalBatches = BigInt.fromI32(0)
  contract.totalAccountsCreated = BigInt.fromI32(0)
  contract.save()

  let account = fetchAccount(address)
  account.save()

  return contract
}
