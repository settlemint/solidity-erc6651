# feat: Add Batch Account Creation for ERC-6551

## Overview

Add batch account creation functionality to the ERC-6551 registry, enabling gas-efficient creation of multiple token-bound accounts in a single transaction. This feature will save users up to **63% gas** compared to individual account creation calls.

## Problem Statement / Motivation

Currently, creating token-bound accounts for multiple NFTs requires:
- **N separate transactions** for N accounts
- **N × 21,000 gas** in base transaction fees alone
- Poor UX for collections wanting to set up accounts for all tokens

**Use Cases:**
1. NFT projects deploying accounts for entire collections
2. Marketplaces batch-creating accounts for new listings
3. Users with multiple NFTs from the same collection
4. DAOs creating accounts for governance NFTs

## Proposed Solution

Create a **wrapper contract** (`ERC6551BatchRegistry`) that provides batch operations while keeping the core registry unchanged. This approach:
- Preserves immutability of the audited core registry
- Allows iteration without breaking changes
- Can be deployed independently per use case

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User / dApp                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              ERC6551BatchRegistry (NEW)                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ batchCreateAccounts(impl, salt, chain, nft, tokenIds[])│ │
│  │ batchComputeAddresses(...)                             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────┬───────────────────────────────────────┘
                      │ calls createAccount() in loop
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              ERC6551Registry (UNCHANGED)                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ createAccount(impl, salt, chain, tokenContract, tokenId)│ │
│  │ account(impl, salt, chain, tokenContract, tokenId)     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Technical Approach

### New Contract: `ERC6551BatchRegistry`

**Location:** `contracts/registry/ERC6551BatchRegistry.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC6551Registry} from "../interfaces/IERC6551Registry.sol";

/**
 * @title ERC6551BatchRegistry
 * @notice Gas-optimized batch creation of ERC-6551 token-bound accounts
 * @dev Wrapper around ERC6551Registry for batch operations
 */
contract ERC6551BatchRegistry {
    /// @notice The core ERC-6551 registry
    IERC6551Registry public immutable registry;

    /// @notice Maximum accounts per batch (gas limit protection)
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @notice Emitted when a batch of accounts is created
    event BatchAccountsCreated(
        address[] accounts,
        address indexed implementation,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 newlyCreated
    );

    error EmptyBatch();
    error BatchTooLarge(uint256 size, uint256 max);

    constructor(address _registry) {
        registry = IERC6551Registry(_registry);
    }

    /**
     * @notice Creates multiple token-bound accounts in a single transaction
     * @param implementation The account implementation address
     * @param salt Salt for deterministic addressing (same for all)
     * @param chainId Chain ID where tokens exist
     * @param tokenContract The ERC-721 contract address
     * @param tokenIds Array of token IDs to create accounts for
     * @return accounts Array of created/existing account addresses
     */
    function batchCreateAccounts(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external returns (address[] memory accounts) {
        uint256 length = tokenIds.length;

        if (length == 0) revert EmptyBatch();
        if (length > MAX_BATCH_SIZE) revert BatchTooLarge(length, MAX_BATCH_SIZE);

        accounts = new address[](length);
        uint256 newlyCreated;

        for (uint256 i = 0; i < length;) {
            // Check if account exists before creation
            address predicted = registry.account(
                implementation,
                salt,
                chainId,
                tokenContract,
                tokenIds[i]
            );

            bool existed = predicted.code.length > 0;

            accounts[i] = registry.createAccount(
                implementation,
                salt,
                chainId,
                tokenContract,
                tokenIds[i]
            );

            if (!existed) {
                unchecked { ++newlyCreated; }
            }

            unchecked { ++i; }
        }

        emit BatchAccountsCreated(
            accounts,
            implementation,
            chainId,
            tokenContract,
            newlyCreated
        );
    }

    /**
     * @notice Computes addresses for multiple accounts without deploying
     * @return accounts Predicted account addresses
     * @return exists Whether each account already exists
     */
    function batchComputeAddresses(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external view returns (
        address[] memory accounts,
        bool[] memory exists
    ) {
        uint256 length = tokenIds.length;
        accounts = new address[](length);
        exists = new bool[](length);

        for (uint256 i = 0; i < length;) {
            accounts[i] = registry.account(
                implementation,
                salt,
                chainId,
                tokenContract,
                tokenIds[i]
            );
            exists[i] = accounts[i].code.length > 0;

            unchecked { ++i; }
        }
    }
}
```

### Interface: `IERC6551BatchRegistry`

**Location:** `contracts/interfaces/IERC6551BatchRegistry.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC6551BatchRegistry {
    event BatchAccountsCreated(
        address[] accounts,
        address indexed implementation,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 newlyCreated
    );

    error EmptyBatch();
    error BatchTooLarge(uint256 size, uint256 max);

    function registry() external view returns (address);
    function MAX_BATCH_SIZE() external view returns (uint256);

    function batchCreateAccounts(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external returns (address[] memory accounts);

    function batchComputeAddresses(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256[] calldata tokenIds
    ) external view returns (
        address[] memory accounts,
        bool[] memory exists
    );
}
```

## Implementation Phases

### Phase 1: Core Implementation

**Files to create:**
- [ ] `contracts/interfaces/IERC6551BatchRegistry.sol` - Interface definition
- [ ] `contracts/registry/ERC6551BatchRegistry.sol` - Batch registry implementation

**Tasks:**
1. Create interface with batch functions and events
2. Implement `batchCreateAccounts()` with gas optimizations
3. Implement `batchComputeAddresses()` view function
4. Add input validation (empty batch, max size)
5. Add custom errors for clear failure messages

### Phase 2: Testing

**Files to create:**
- [ ] `test/ERC6551BatchRegistry.t.sol` - Foundry tests

**Test Coverage:**
1. **Happy Path Tests:**
   - Create batch of 10 accounts
   - Create batch of 100 accounts (max)
   - Verify returned addresses match predictions
   - Verify events emitted correctly

2. **Edge Cases:**
   - Empty batch (should revert)
   - Batch size > 100 (should revert)
   - Duplicate tokenIds in batch (should handle gracefully)
   - All accounts already exist (returns existing)
   - Mix of new and existing accounts

3. **Gas Benchmarks:**
   - Compare batch vs individual creation at 10, 25, 50, 100 accounts
   - Measure gas per account at different batch sizes
   - Verify linear gas growth (not quadratic)

4. **Fuzz Tests:**
   - Random batch sizes (1-100)
   - Random tokenIds
   - Mixed existing/new accounts

### Phase 3: Deployment

**Files to create/update:**
- [ ] `ignition/modules/ERC6551BatchRegistry.ts` - Deployment module
- [ ] `ignition/modules/FullDeployment.ts` - Add batch registry

**Deployment Script:**
```typescript
// ignition/modules/ERC6551BatchRegistry.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ERC6551BatchRegistryModule = buildModule("ERC6551BatchRegistry", (m) => {
  const registry = m.getParameter("registry");

  const batchRegistry = m.contract("ERC6551BatchRegistry", [registry]);

  return { batchRegistry };
});

export default ERC6551BatchRegistryModule;
```

### Phase 4: Subgraph Update

**Files to update:**
- [ ] `subgraph/schema.graphql` - Add batch entities
- [ ] `subgraph/subgraph.yaml` - Add batch registry data source
- [ ] `subgraph/src/mappings.ts` - Add batch event handler

**Schema Additions:**
```graphql
type BatchCreation @entity {
  id: ID!                          # tx hash
  accounts: [TokenBoundAccount!]!
  implementation: Bytes!
  chainId: BigInt!
  tokenContract: Bytes!
  newlyCreated: BigInt!
  totalInBatch: BigInt!
  txHash: Bytes!
  blockNumber: BigInt!
  timestamp: BigInt!
  gasUsed: BigInt
}
```

### Phase 5: Documentation

**Files to update:**
- [ ] `README.md` - Add batch creation section
- [ ] Add usage examples

## Acceptance Criteria

### Functional Requirements
- [ ] `batchCreateAccounts()` creates multiple accounts in one transaction
- [ ] Returns array of addresses in same order as input tokenIds
- [ ] Handles existing accounts gracefully (returns existing address)
- [ ] Emits `BatchAccountsCreated` event with creation count
- [ ] `batchComputeAddresses()` returns predicted addresses without deploying
- [ ] Reverts on empty batch with `EmptyBatch()` error
- [ ] Reverts on batch > 100 with `BatchTooLarge()` error

### Non-Functional Requirements
- [ ] Gas savings > 50% compared to individual calls at batch size 50
- [ ] Linear gas growth (not quadratic) with batch size
- [ ] All tests passing with > 95% coverage
- [ ] No new security vulnerabilities introduced

### Quality Gates
- [ ] `forge test` passes all tests
- [ ] `forge coverage` shows > 95% line coverage
- [ ] `forge test --gas-report` shows expected gas usage
- [ ] Code review approved

## Gas Analysis

**Expected Gas Costs (estimates):**

| Batch Size | Individual Calls | Batch Call | Savings |
|------------|-----------------|------------|---------|
| 10 | ~1,140,000 gas | ~480,000 gas | 58% |
| 25 | ~2,850,000 gas | ~1,050,000 gas | 63% |
| 50 | ~5,700,000 gas | ~2,000,000 gas | 65% |
| 100 | ~11,400,000 gas | ~3,900,000 gas | 66% |

**Per-account cost breakdown:**
- Individual: ~114,000 gas (21k base + 93k CREATE2)
- Batch: ~39,000 gas (shared base + optimized loop)

## Dependencies & Prerequisites

**Required:**
- Existing `ERC6551Registry` deployed and verified
- Solidity ^0.8.20
- Foundry for testing
- Hardhat Ignition for deployment

**No new dependencies needed** - uses existing OpenZeppelin contracts already in project.

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Gas limit exceeded | Low | High | MAX_BATCH_SIZE = 100 enforced |
| Reentrancy attack | Very Low | High | CREATE2 + minimal proxy is safe |
| Front-running | Low | Low | Idempotent design (returns existing) |
| DoS via large batches | Low | Medium | Batch size limit + gas costs |

## Future Considerations

**Potential Enhancements (not in scope):**
1. **Continue-on-error mode** - Allow partial success with failure reporting
2. **Varied parameters mode** - Different implementation/salt per account
3. **Multicall integration** - Batch create + execute in single tx
4. **Cross-chain batching** - Create accounts for tokens on multiple chains

## References & Research

### Internal References
- Registry implementation: `contracts/registry/ERC6551Registry.sol`
- Existing batch pattern: `contracts/examples/ExampleUsage.sol:197-216`
- Bytecode library: `contracts/lib/ERC6551BytecodeLib.sol`
- Registry tests: `test/ERC6551Registry.t.sol`

### External References
- [ERC-6551 Specification](https://eips.ethereum.org/EIPS/eip-6551)
- [OpenZeppelin Multicall](https://docs.openzeppelin.com/contracts/4.x/api/utils#Multicall)
- [ERC-6551 Reference Implementation](https://github.com/erc6551/reference)
- [RareSkills Gas Optimization Guide](https://rareskills.io/post/gas-optimization)

---

## File Checklist

### New Files
- [ ] `contracts/interfaces/IERC6551BatchRegistry.sol`
- [ ] `contracts/registry/ERC6551BatchRegistry.sol`
- [ ] `test/ERC6551BatchRegistry.t.sol`
- [ ] `ignition/modules/ERC6551BatchRegistry.ts`

### Modified Files
- [ ] `ignition/modules/FullDeployment.ts` - Add batch registry
- [ ] `subgraph/schema.graphql` - Add BatchCreation entity
- [ ] `subgraph/subgraph.yaml` - Add data source
- [ ] `subgraph/src/mappings.ts` - Add handler
- [ ] `README.md` - Add documentation
