![logo](https://github.com/settlemint/solidity-token-erc6551/blob/main/OG_Solidity.jpg)

[https://settlemint.com](https://settlemint.com)

Build your own blockchain usecase with ease.

[![CI status](https://github.com/settlemint/solidity-token-erc6551/actions/workflows/solidity.yml/badge.svg?event=push&branch=main)](https://github.com/settlemint/solidity-token-erc6551/actions?query=branch%3Amain) [![License](https://img.shields.io/npm/l/@settlemint/solidity-token-erc6551)](https://fsl.software) [![npm](https://img.shields.io/npm/dw/@settlemint/solidity-token-erc6551)](https://www.npmjs.com/package/@settlemint/solidity-token-erc6551) [![stars](https://img.shields.io/github/stars/settlemint/solidity-token-erc6551)](https://github.com/settlemint/solidity-token-erc6551)

[Documentation](https://console.settlemint.com/documentation/) • [Discord](https://discord.com/invite/Mt5yqFrey9) • [NPM](https://www.npmjs.com/package/@settlemint/solidity-token-erc6551) • [Issues](https://github.com/settlemint/solidity-token-erc6551/issues)

## Get started

Launch this smart contract set in SettleMint under the `Smart Contract Sets` section. This will automatically link it to your own blockchain node and make use of the private keys living in the platform.

If you want to use it separately, bootstrap a new project using

```shell
forge init my-project --template settlemint/solidity-token-erc6551
```

Or if you want to use this set as a dependency of your own,

```shell
bun install @settlemint/solidity-token-erc6551
```

## ERC-6551: Token Bound Accounts

This project implements the [ERC-6551](https://eips.ethereum.org/EIPS/eip-6551) standard for Token Bound Accounts (TBAs) - smart contract wallets owned by NFTs. Each NFT can have its own account that can hold assets and execute transactions.

### Core Contracts

| Contract | Description |
|----------|-------------|
| `ERC6551Registry` | Central registry for creating accounts using CREATE2 |
| `ERC6551BatchRegistry` | Gas-optimized batch creation (58-66% savings) |
| `TokenBoundAccount` | Base account implementation with execution capabilities |
| `ERC1271TokenBoundAccount` | Extended account with ERC-1271 signature validation |

### Key Features

- **Deterministic addresses** - Same address on any chain with same parameters
- **Minimal proxies** - Each TBA is only 173 bytes of deployed code
- **Immutable binding** - Token info stored in bytecode, never changes
- **Composable** - TBAs can hold ETH, ERC-20s, NFTs, and other TBAs

## DX: Foundry & Hardhat hybrid

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

**Hardhat is a Flexible, Extensible, Fast Ethereum development environment for professionals in typescript**

Hardhat consists of:

- **Hardhat Runner**: Hardhat Runner is the main component you interact with when using Hardhat. It's a flexible and extensible task runner that helps you manage and automate the recurring tasks inherent to developing smart contracts and dApps.
- **Hardhat Ignition**: Declarative deployment system that enables you to deploy your smart contracts without navigating the mechanics of the deployment process.
- **Hardhat Network**: Declarative deployment system that enables you to deploy your smart contracts without navigating the mechanics of the deployment process.

## Deployment

### Using SettleMint Platform (Recommended)

The SettleMint CLI handles all configuration automatically - no `.env` files needed.

```bash
# 1. Install the CLI (if not already installed)
bun add @settlemint/sdk-cli

# 2. Login to SettleMint
bunx settlemint login

# 3. Connect to your application (select workspace, app, blockchain node, and graph middleware)
bunx settlemint connect

# 4. Deploy contracts to your blockchain node
bunx settlemint scs hardhat deploy remote --blockchain-node <your-node-name> -m ignition/modules/main.ts

# 5. Build and deploy the subgraph
bunx settlemint scs subgraph build
bunx settlemint scs subgraph deploy <subgraph-name>
```

### Using Local Anvil

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
npx hardhat ignition deploy ignition/modules/main.ts --network localhost
```

### VS Code Tasks

Use the pre-configured VS Code tasks (Ctrl+Shift+P → "Tasks: Run Task"):
- **SettleMint - Login**: Authenticate with the platform
- **Hardhat - Deploy to platform network**: Deploy contracts
- **The Graph - Deploy or update the subgraph**: Deploy subgraph

## Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run specific test file
forge test --match-path test/ERC6551Registry.t.sol
```

## Documentation

- Additional documentation can be found in the [docs folder](./docs).
- [SettleMint Documentation](https://console.settlemint.com/documentation/docs/using-platform/dev-tools/code-studio/smart-contract-sets/deploying-a-contract/)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Hardhat Documentation](https://hardhat.org/hardhat-runner/docs/getting-started)
- [ERC-6551 Specification](https://eips.ethereum.org/EIPS/eip-6551)


