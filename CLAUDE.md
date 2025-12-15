# ERC-6551 Token Bound Accounts

## Project Overview

This project implements the ERC-6551 standard for Token Bound Accounts (TBAs) - smart contract wallets owned by NFTs. Each NFT can have its own account that can hold assets and execute transactions.

## Quick Start

```bash
# Install dependencies
bun install
forge install

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Deploy locally (Anvil)
anvil &
npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network localhost
```

## Architecture

### Core Contracts

- **`contracts/registry/ERC6551Registry.sol`** - Creates TBAs using CREATE2 for deterministic addresses
- **`contracts/registry/ERC6551BatchRegistry.sol`** - Gas-optimized batch creation (58-66% savings)
- **`contracts/account/TokenBoundAccount.sol`** - Base account implementation with execute function
- **`contracts/account/ERC1271TokenBoundAccount.sol`** - Extended account with ERC-1271 signature validation

### Libraries

- **`contracts/lib/ERC6551BytecodeLib.sol`** - Generates ERC-1167 minimal proxy bytecode with immutable token data

### Key Design Decisions

1. **ERC-1167 Minimal Proxies** - Each TBA is only 173 bytes of deployed code
2. **Immutable Token Binding** - Token info stored in bytecode, never changes
3. **CREATE2 Determinism** - Same address on any chain with same parameters
4. **Idempotent Creation** - Creating an existing account returns the existing address

## Testing

```bash
# All tests
forge test

# Specific test file
forge test --match-path test/ERC6551BatchRegistry.t.sol

# Fuzz testing
forge test --match-test testFuzz -vvv

# Gas report
forge test --gas-report
```

## Deployment

### Local (Anvil)

```bash
anvil
npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network localhost
```

### Besu Network

Configure `hardhat.config.ts` with your Besu RPC endpoint, then:

```bash
npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network besu
```

## Key Files

| File | Purpose |
|------|---------|
| `contracts/registry/ERC6551Registry.sol` | Core registry |
| `contracts/registry/ERC6551BatchRegistry.sol` | Batch operations |
| `contracts/account/TokenBoundAccount.sol` | Account implementation |
| `test/*.t.sol` | Foundry tests |
| `ignition/modules/FullDeployment.ts` | Deployment module |
| `subgraph/` | Graph Protocol indexing |

## Gas Benchmarks

| Operation | Gas Cost |
|-----------|----------|
| Create single account | ~85k |
| Batch create (per account) | ~77k |
| Execute (ETH transfer) | ~35k |

## Security Notes

- Authorization checks before all execute operations
- Only NFT owner can execute transactions
- DELEGATECALL (operation type 1) allows storage modification - use with caution
- Cross-chain: `token()` returns correct data but `owner()` returns address(0) if on different chain
