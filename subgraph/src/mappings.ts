import { BigInt, Bytes, log } from "@graphprotocol/graph-ts";
import { ERC6551AccountCreated } from "../generated/ERC6551Registry/ERC6551Registry";
import { BatchAccountsCreated } from "../generated/ERC6551BatchRegistry/ERC6551BatchRegistry";
import {
  TokenBoundAccount,
  AccountCreatedEvent,
  Registry,
  TokenContract,
  ImplementationContract,
  BatchCreation,
  BatchRegistry,
} from "../generated/schema";

// Registry ID (update this to match your deployed registry address)
const REGISTRY_ID = "0x0000000000000000000000000000000000000000";

/**
 * Handles the ERC6551AccountCreated event
 * Creates or updates all related entities
 */
export function handleERC6551AccountCreated(event: ERC6551AccountCreated): void {
  let accountId = event.params.account.toHexString().toLowerCase();
  let txHash = event.transaction.hash;
  let logIndex = event.logIndex;
  let eventId = txHash.toHexString() + "-" + logIndex.toString();

  // Load or create the account entity
  let account = TokenBoundAccount.load(accountId);
  if (account == null) {
    account = new TokenBoundAccount(accountId);
    account.implementation = event.params.implementation;
    account.chainId = BigInt.fromI32(event.params.chainId.toI32());
    account.tokenContract = event.params.tokenContract;
    account.tokenId = event.params.tokenId;
    account.salt = event.params.salt;
    account.createdAtBlock = event.block.number;
    account.createdAtTx = txHash;
    account.createdAtTimestamp = event.block.timestamp;
    account.creationEvent = eventId;
    account.save();

    log.info("Created TokenBoundAccount: {}", [accountId]);
  }

  // Create the event entity
  let createdEvent = new AccountCreatedEvent(eventId);
  createdEvent.account = accountId;
  createdEvent.implementation = event.params.implementation;
  createdEvent.chainId = BigInt.fromI32(event.params.chainId.toI32());
  createdEvent.tokenContract = event.params.tokenContract;
  createdEvent.tokenId = event.params.tokenId;
  createdEvent.salt = event.params.salt;
  createdEvent.txHash = txHash;
  createdEvent.blockNumber = event.block.number;
  createdEvent.timestamp = event.block.timestamp;
  createdEvent.logIndex = logIndex;
  createdEvent.save();

  // Update registry stats
  updateRegistry(event);

  // Update token contract stats
  updateTokenContract(event);

  // Update implementation stats
  updateImplementation(event);
}

/**
 * Updates the Registry entity with aggregate statistics
 */
function updateRegistry(event: ERC6551AccountCreated): void {
  let registryId = event.address.toHexString().toLowerCase();
  let registry = Registry.load(registryId);

  if (registry == null) {
    registry = new Registry(registryId);
    registry.totalAccounts = BigInt.fromI32(0);
    registry.firstEventBlock = event.block.number;
  }

  registry.totalAccounts = registry.totalAccounts.plus(BigInt.fromI32(1));
  registry.lastEventBlock = event.block.number;
  registry.save();
}

/**
 * Updates the TokenContract entity to track accounts per NFT contract
 */
function updateTokenContract(event: ERC6551AccountCreated): void {
  let tokenContractId = event.params.tokenContract.toHexString().toLowerCase();
  let tokenContract = TokenContract.load(tokenContractId);

  if (tokenContract == null) {
    tokenContract = new TokenContract(tokenContractId);
    tokenContract.accountCount = BigInt.fromI32(0);
    tokenContract.tokenIds = [];
  }

  tokenContract.accountCount = tokenContract.accountCount.plus(BigInt.fromI32(1));

  // Add token ID if not already tracked
  let tokenIds = tokenContract.tokenIds;
  let tokenId = event.params.tokenId;
  let found = false;
  for (let i = 0; i < tokenIds.length; i++) {
    if (tokenIds[i].equals(tokenId)) {
      found = true;
      break;
    }
  }
  if (!found) {
    tokenIds.push(tokenId);
    tokenContract.tokenIds = tokenIds;
  }

  tokenContract.save();
}

/**
 * Updates the ImplementationContract entity to track implementation usage
 */
function updateImplementation(event: ERC6551AccountCreated): void {
  let implementationId = event.params.implementation.toHexString().toLowerCase();
  let implementation = ImplementationContract.load(implementationId);

  if (implementation == null) {
    implementation = new ImplementationContract(implementationId);
    implementation.accountCount = BigInt.fromI32(0);
    implementation.firstUsedAtBlock = event.block.number;
  }

  implementation.accountCount = implementation.accountCount.plus(BigInt.fromI32(1));
  implementation.lastUsedAtBlock = event.block.number;
  implementation.save();
}

/**
 * Handles the BatchAccountsCreated event from ERC6551BatchRegistry
 * Creates BatchCreation entity and updates BatchRegistry stats
 */
export function handleBatchAccountsCreated(event: BatchAccountsCreated): void {
  let txHash = event.transaction.hash;
  let logIndex = event.logIndex;
  let batchId = txHash.toHexString() + "-" + logIndex.toString();

  // Create BatchCreation entity
  let batch = new BatchCreation(batchId);

  // Map account addresses to entity IDs
  let accountIds: string[] = [];
  let accounts = event.params.accounts;
  for (let i = 0; i < accounts.length; i++) {
    accountIds.push(accounts[i].toHexString().toLowerCase());
  }
  batch.accounts = accountIds;

  batch.implementation = event.params.implementation;
  batch.chainId = event.params.chainId;
  batch.tokenContract = event.params.tokenContract;
  batch.newlyCreated = event.params.newlyCreated;
  batch.totalInBatch = BigInt.fromI32(accounts.length);
  batch.txHash = txHash;
  batch.blockNumber = event.block.number;
  batch.timestamp = event.block.timestamp;
  batch.save();

  log.info("Created BatchCreation: {} with {} accounts", [
    batchId,
    accounts.length.toString(),
  ]);

  // Update BatchRegistry stats
  updateBatchRegistry(event);
}

/**
 * Updates the BatchRegistry entity with aggregate statistics
 */
function updateBatchRegistry(event: BatchAccountsCreated): void {
  let batchRegistryId = event.address.toHexString().toLowerCase();
  let batchRegistry = BatchRegistry.load(batchRegistryId);

  if (batchRegistry == null) {
    batchRegistry = new BatchRegistry(batchRegistryId);
    batchRegistry.totalBatches = BigInt.fromI32(0);
    batchRegistry.totalAccountsCreated = BigInt.fromI32(0);
    batchRegistry.firstEventBlock = event.block.number;
  }

  batchRegistry.totalBatches = batchRegistry.totalBatches.plus(BigInt.fromI32(1));
  batchRegistry.totalAccountsCreated = batchRegistry.totalAccountsCreated.plus(
    BigInt.fromI32(event.params.accounts.length)
  );
  batchRegistry.lastEventBlock = event.block.number;
  batchRegistry.save();
}
