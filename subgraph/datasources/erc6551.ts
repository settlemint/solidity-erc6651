import {
  Address,
  BigInt,
} from '@graphprotocol/graph-ts'

import {
  AccountCreatedEvent,
  TokenBoundAccount,
} from '../../generated/schema'

import {
  ERC6551AccountCreated as ERC6551AccountCreatedEvent,
} from '../../generated/erc6551/IERC6551Registry'

import {
  events,
  transactions,
} from '@amxx/graphprotocol-utils'

import {
  fetchAccount,
} from '../fetch/account'

import {
  fetchERC6551,
  fetchTokenBoundAccount,
  fetchTokenContract,
  fetchImplementationContract,
} from '../fetch/erc6551'

export function handleERC6551AccountCreated(event: ERC6551AccountCreatedEvent): void {
  let registry = fetchERC6551(event.address)
  if (registry != null) {
    let account = fetchTokenBoundAccount(
      registry,
      event.params.account,
      event.params.implementation,
      event.params.chainId,
      event.params.tokenContract,
      event.params.tokenId,
      event.params.salt,
      event.block.number
    )

    let from = fetchAccount(event.transaction.from)

    // Set creation metadata
    account.createdAtBlock = event.block.number
    account.createdAtTimestamp = event.block.timestamp
    account.owner = from.id

    // Update registry stats
    registry.totalAccounts = registry.totalAccounts.plus(BigInt.fromI32(1))
    registry.lastEventBlock = event.block.number
    if (registry.firstEventBlock === null) {
      registry.firstEventBlock = event.block.number
    }

    // Update token contract stats
    let tokenContract = fetchTokenContract(event.params.tokenContract)
    tokenContract.accountCount = tokenContract.accountCount.plus(BigInt.fromI32(1))
    tokenContract.save()

    // Update implementation stats
    let implementation = fetchImplementationContract(event.params.implementation, event.block.number)
    implementation.accountCount = implementation.accountCount.plus(BigInt.fromI32(1))
    implementation.lastUsedAtBlock = event.block.number
    implementation.save()

    // Create event entity
    let ev = new AccountCreatedEvent(events.id(event))
    ev.emitter = registry.id
    ev.transaction = transactions.log(event).id
    ev.timestamp = event.block.timestamp
    ev.registry = registry.id
    ev.account = account.id
    ev.implementation = event.params.implementation
    ev.chainId = event.params.chainId
    ev.tokenContract = event.params.tokenContract
    ev.tokenId = event.params.tokenId
    ev.salt = event.params.salt
    ev.from = from.id

    // Link event to account
    account.creationEvent = ev.id

    // Save all entities
    registry.save()
    account.save()
    ev.save()
    from.save()
  }
}
