import {
  Address,
  BigInt,
  Bytes,
} from '@graphprotocol/graph-ts'

import {
  Account,
  ERC6551Contract,
  TokenBoundAccount,
  TokenContract,
  ImplementationContract,
} from '../../generated/schema'

import {
  fetchAccount
} from './account'

export function fetchERC6551(address: Address): ERC6551Contract | null {
  let id = address

  // Try load entry
  let contract = ERC6551Contract.load(id)
  if (contract != null) {
    return contract
  }

  // Create new entry
  contract = new ERC6551Contract(id)
  contract.asAccount = address
  contract.totalAccounts = BigInt.fromI32(0)
  contract.save()

  let account = fetchAccount(address)
  account.asERC6551 = id
  account.save()

  return contract
}

export function fetchTokenBoundAccount(
  registry: ERC6551Contract,
  accountAddress: Address,
  implementationAddress: Address,
  chainId: BigInt,
  tokenContractAddress: Address,
  tokenId: BigInt,
  salt: Bytes,
  blockNumber: BigInt
): TokenBoundAccount {
  let id = accountAddress

  let account = TokenBoundAccount.load(id)
  if (account == null) {
    // Fetch or create related entities
    let tokenContract = fetchTokenContract(tokenContractAddress)
    tokenContract.save()

    let implementation = fetchImplementationContract(implementationAddress, blockNumber)
    implementation.save()

    account = new TokenBoundAccount(id)
    account.registry = registry.id
    account.implementation = implementation.id
    account.chainId = chainId
    account.tokenContract = tokenContract.id
    account.tokenId = tokenId
    account.salt = salt
    account.createdAtBlock = BigInt.fromI32(0)
    account.createdAtTimestamp = BigInt.fromI32(0)
  }

  return account as TokenBoundAccount
}

export function fetchTokenContract(address: Address): TokenContract {
  let id = address

  let contract = TokenContract.load(id)
  if (contract == null) {
    contract = new TokenContract(id)
    contract.accountCount = BigInt.fromI32(0)
  }

  return contract as TokenContract
}

export function fetchImplementationContract(address: Address, blockNumber: BigInt): ImplementationContract {
  let id = address

  let contract = ImplementationContract.load(id)
  if (contract == null) {
    contract = new ImplementationContract(id)
    contract.accountCount = BigInt.fromI32(0)
    contract.firstUsedAtBlock = blockNumber
    contract.lastUsedAtBlock = blockNumber
  }

  return contract as ImplementationContract
}
