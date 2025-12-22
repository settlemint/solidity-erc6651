import {
  Address,
  BigInt,
} from '@graphprotocol/graph-ts'

import {
  BatchCreation,
  ERC6551BatchContract,
} from '../../generated/schema'

import {
  BatchAccountsCreated as BatchAccountsCreatedEvent,
} from '../../generated/erc6551batch/IERC6551BatchRegistry'

import {
  events,
  transactions,
} from '@amxx/graphprotocol-utils'

import {
  fetchAccount,
} from '../fetch/account'

import {
  fetchERC6551Batch,
} from '../fetch/erc6551batch'

export function handleBatchAccountsCreated(event: BatchAccountsCreatedEvent): void {
  let registry = fetchERC6551Batch(event.address)
  if (registry != null) {
    let batchId = events.id(event)

    // Create batch entity
    let batch = new BatchCreation(batchId)
    batch.registry = registry.id

    // Map account addresses to string IDs
    let accountIds: string[] = []
    let accounts = event.params.accounts
    for (let i = 0; i < accounts.length; i++) {
      accountIds.push(accounts[i].toHexString().toLowerCase())
    }
    batch.accounts = accountIds
    batch.implementation = event.params.implementation
    batch.chainId = event.params.chainId
    batch.tokenContract = event.params.tokenContract
    batch.newlyCreated = event.params.newlyCreated
    batch.totalInBatch = BigInt.fromI32(accounts.length)
    batch.blockNumber = event.block.number
    batch.timestamp = event.block.timestamp

    // Update registry stats
    registry.totalBatches = registry.totalBatches.plus(BigInt.fromI32(1))
    registry.totalAccountsCreated = registry.totalAccountsCreated.plus(BigInt.fromI32(accounts.length))
    registry.lastEventBlock = event.block.number
    if (registry.firstEventBlock === null) {
      registry.firstEventBlock = event.block.number
    }

    // Save entities
    registry.save()
    batch.save()
  }
}
