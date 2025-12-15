# ERC-6551 Token Bound Accounts

A production-ready implementation of [ERC-6551](https://eips.ethereum.org/EIPS/eip-6551) Token Bound Accounts with optional ERC-1271 signature validation support.

## Overview

ERC-6551 defines a system that gives every ERC-721 token a smart contract account. These token-bound accounts (TBAs) allow NFTs to:

- **Own assets**: Hold ETH, ERC-20 tokens, other NFTs, and any on-chain assets
- **Execute transactions**: Interact with any smart contract
- **Build identity**: Accumulate on-chain history and reputation tied to the NFT
- **Compose infinitely**: Create complex nested ownership structures

## Contract Sets

This repository provides two implementation sets:

### Core Set: ERC-6551

The foundational implementation for token-bound accounts:

| Contract | Description |
|----------|-------------|
| `ERC6551Registry` | Central registry for creating accounts using CREATE2 |
| `TokenBoundAccount` | Base account implementation with execution capabilities |
| `ERC6551BytecodeLib` | Library for bytecode generation and address computation |

### Extended Set: ERC-6551 + ERC-1271

Adds signature validation capabilities for off-chain authorization:

| Contract | Description |
|----------|-------------|
| `ERC1271TokenBoundAccount` | Extended account with ERC-1271 signature validation |

### Batch Operations

Gas-optimized batch account creation:

| Contract | Description |
|----------|-------------|
| `ERC6551BatchRegistry` | Batch wrapper for creating multiple accounts in one transaction |

**Gas Savings:**
| Batch Size | Individual Calls | Batch Call | Savings |
|------------|-----------------|------------|---------|
| 10 | ~1,140,000 gas | ~480,000 gas | 58% |
| 50 | ~5,700,000 gas | ~2,000,000 gas | 65% |
| 100 | ~11,400,000 gas | ~3,900,000 gas | 66% |

## Architecture

```
                    ┌─────────────────────┐
                    │   ERC6551Registry   │
                    │                     │
                    │  createAccount()    │
                    │  account()          │
                    └──────────┬──────────┘
                               │
                               │ deploys (CREATE2)
                               ▼
┌──────────────────────────────────────────────────┐
│              Minimal Proxy (EIP-1167)            │
│  ┌──────────────────────────────────────────┐   │
│  │         TokenBoundAccount                │   │
│  │  ┌────────────────────────────────────┐  │   │
│  │  │  OR  ERC1271TokenBoundAccount     │  │   │
│  │  └────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │  Immutable Data:                         │   │
│  │  • salt                                  │   │
│  │  • chainId                               │   │
│  │  • tokenContract                         │   │
│  │  • tokenId                               │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) >= 18
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (for testing)

### Installation

```bash
# Clone the repository
git clone https://github.com/settlemint/solidity-token-erc6551.git
cd solidity-token-erc6551

# Install dependencies
npm install

# Install Foundry dependencies
forge install
```

### Compile Contracts

```bash
# Using Hardhat
npm run build

# Or using Foundry
forge build
```

### Run Tests

```bash
# Using Foundry (recommended)
npm run test

# With gas report
npm run test:gas
```

### Deploy Contracts

```bash
# Deploy to local network
npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network localhost

# Deploy to a specific network
npx hardhat ignition deploy ignition/modules/FullDeployment.ts --network sepolia
```

## Usage

### Creating a Token Bound Account

```solidity
import {IERC6551Registry} from "@settlemint/solidity-token-erc6551/contracts/interfaces/IERC6551Registry.sol";

// Get the registry instance
IERC6551Registry registry = IERC6551Registry(REGISTRY_ADDRESS);

// Compute the account address (doesn't deploy)
address accountAddress = registry.account(
    implementation,  // TokenBoundAccount implementation address
    salt,           // bytes32 salt for multiple accounts per token
    block.chainid,  // Chain ID
    tokenContract,  // ERC-721 contract address
    tokenId         // Token ID
);

// Create the account (deploys if not exists)
address account = registry.createAccount(
    implementation,
    salt,
    block.chainid,
    tokenContract,
    tokenId
);
```

### Executing Transactions

```solidity
import {IERC6551Executable} from "@settlemint/solidity-token-erc6551/contracts/interfaces/IERC6551Executable.sol";

// Get the account instance (only NFT owner can execute)
IERC6551Executable account = IERC6551Executable(accountAddress);

// Execute a simple ETH transfer
account.execute(
    recipient,  // Target address
    1 ether,    // ETH value
    "",         // Calldata (empty for simple transfer)
    0           // Operation: 0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2
);

// Execute a contract call
bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount);
account.execute(tokenAddress, 0, data, 0);
```

### Validating Signatures (ERC-1271)

```solidity
import {IERC1271} from "@settlemint/solidity-token-erc6551/contracts/interfaces/IERC1271.sol";

// Check if a signature is valid
bytes4 result = IERC1271(accountAddress).isValidSignature(hash, signature);

if (result == 0x1626ba7e) {
    // Signature is valid - signed by the NFT owner
}
```

### Batch Account Creation

```solidity
import {IERC6551BatchRegistry} from "@settlemint/solidity-token-erc6551/contracts/interfaces/IERC6551BatchRegistry.sol";

// Get the batch registry instance
IERC6551BatchRegistry batchRegistry = IERC6551BatchRegistry(BATCH_REGISTRY_ADDRESS);

// Create token IDs array
uint256[] memory tokenIds = new uint256[](3);
tokenIds[0] = 1;
tokenIds[1] = 2;
tokenIds[2] = 3;

// Batch create accounts (up to 100 per transaction)
address[] memory accounts = batchRegistry.batchCreateAccounts(
    implementation,  // TokenBoundAccount implementation address
    salt,           // bytes32 salt (same for all)
    block.chainid,  // Chain ID
    tokenContract,  // ERC-721 contract address
    tokenIds        // Array of token IDs
);

// Pre-compute addresses without deploying
(address[] memory addresses, bool[] memory exists) = batchRegistry.batchComputeAddresses(
    implementation,
    salt,
    block.chainid,
    tokenContract,
    tokenIds
);
```

## Supported Operations

The `execute` function supports four operation types:

| Code | Operation | Description |
|------|-----------|-------------|
| 0 | CALL | Standard external call |
| 1 | DELEGATECALL | Delegate call (preserves context) |
| 2 | CREATE | Deploy a new contract |
| 3 | CREATE2 | Deploy with deterministic address |

## Interface IDs (ERC-165)

| Interface | ID |
|-----------|-----|
| IERC6551Account | `0x6faff5f1` |
| IERC6551Executable | `0x51945447` |
| IERC1271 | `0x1626ba7e` |
| IERC165 | `0x01ffc9a7` |

## Subgraph

This repository includes a Graph Protocol subgraph for indexing token-bound accounts.

### Deploying the Subgraph

1. Update `subgraph/subgraph.yaml` with your registry address and start block
2. Generate types:
   ```bash
   cd subgraph
   graph codegen
   ```
3. Build:
   ```bash
   graph build
   ```
4. Deploy:
   ```bash
   graph deploy --studio your-subgraph-name
   ```

### Indexed Data

The subgraph tracks:

- **TokenBoundAccount**: All deployed accounts with their bound tokens
- **AccountCreatedEvent**: Raw event data for each creation
- **Registry**: Aggregate statistics
- **TokenContract**: Accounts grouped by NFT contract
- **ImplementationContract**: Usage by implementation
- **BatchCreation**: Batch operation records
- **BatchRegistry**: Batch registry statistics

### Example Query

```graphql
{
  tokenBoundAccounts(first: 10, orderBy: createdAtBlock, orderDirection: desc) {
    id
    tokenContract
    tokenId
    chainId
    createdAtTimestamp
  }
}
```

## Project Structure

```
solidity-token-erc6551/
├── contracts/
│   ├── interfaces/          # Interface definitions
│   │   ├── IERC6551Account.sol
│   │   ├── IERC6551Executable.sol
│   │   ├── IERC6551Registry.sol
│   │   ├── IERC6551BatchRegistry.sol
│   │   └── IERC1271.sol
│   ├── account/            # Account implementations
│   │   ├── TokenBoundAccount.sol
│   │   └── ERC1271TokenBoundAccount.sol
│   ├── registry/           # Registry contracts
│   │   ├── ERC6551Registry.sol
│   │   └── ERC6551BatchRegistry.sol
│   ├── lib/               # Libraries
│   │   └── ERC6551BytecodeLib.sol
│   └── examples/          # Example contracts
│       ├── ExampleNFT.sol
│       └── ExampleUsage.sol
├── ignition/modules/      # Deployment modules
├── test/                  # Foundry tests
├── scripts/              # Helper scripts
├── subgraph/             # The Graph subgraph
└── README.md
```

## Security Considerations

### Ownership Cycles

**Warning**: Never transfer an NFT to its own token-bound account. This creates an ownership cycle that permanently locks all assets.

```solidity
// DON'T DO THIS - Assets will be locked forever
nft.transferFrom(owner, tokenBoundAccount, tokenId);
```

### Cross-Chain Accounts

Accounts bound to tokens on different chains will have `owner() == address(0)` on the current chain. Always verify the chain ID matches before trusting ownership:

```solidity
(uint256 chainId, , ) = account.token();
require(chainId == block.chainid, "Token on different chain");
```

### State Verification

Use the `state()` function to detect if an account's state has changed between transactions:

```solidity
uint256 stateBefore = account.state();
// ... some operations
require(account.state() == stateBefore, "Account state changed");
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Resources

- [ERC-6551 Specification](https://eips.ethereum.org/EIPS/eip-6551)
- [ERC-1271 Specification](https://eips.ethereum.org/EIPS/eip-1271)
- [EIP-1167 Minimal Proxy](https://eips.ethereum.org/EIPS/eip-1167)
- [Reference Implementation](https://github.com/erc6551/reference)

## Support

For questions and support:
- [GitHub Issues](https://github.com/settlemint/solidity-token-erc6551/issues)
- [SettleMint Support](mailto:support@settlemint.com)
