# SettleMint BTP End-to-End Deployment Guide

Complete runbook for deploying ERC-6551 Token Bound Accounts on SettleMint BTP.

## 1. Prerequisites

- **Node.js** >= 20
- **bun** (package manager)
- **Foundry** (`forge`) for Solidity compilation
- **SettleMint account** with an active workspace and application
- This repository cloned locally

## 2. Install and Login

```bash
bun install
bunx settlemint login
```

## 3. Provision Infrastructure

Create the blockchain network and supporting middleware:

```bash
# Besu network + node
bunx settlemint platform create blockchain-network besu erc6551-network \
  --node-name node1 --accept-defaults -d -w

# The Graph middleware
bunx settlemint platform create middleware graph erc6551-graph \
  --blockchain-node node1 --accept-defaults -d -w

# (Optional) Blockscout explorer
bunx settlemint platform create insights blockscout erc6551-explorer \
  --blockchain-node node1 --accept-defaults -d -w
```

## 4. Connect and Configure

### 4.1 Connect to your application

```bash
bunx settlemint connect
```

Select your workspace, application, blockchain node, and Graph middleware when prompted.

### 4.2 Create `.env` file

The CLI stores auth credentials locally but other commands need a `.env` file. Copy the template and fill in your values:

```bash
cp .env.example .env
```

Then edit `.env` with values from the SettleMint console:

| Key                                            | Where to find it                                                |
| ---------------------------------------------- | --------------------------------------------------------------- |
| `SETTLEMINT_WORKSPACE`                         | From `settlemint connect` output (e.g. `customer-success-2384`) |
| `SETTLEMINT_APPLICATION`                       | From `settlemint connect` output (e.g. `ntt-erc6551-01f80`)     |
| `SETTLEMINT_BLOCKCHAIN_NODE`                   | Your node's unique name (e.g. `node1-3b7fc`)                    |
| `SETTLEMINT_BLOCKCHAIN_NODE_JSON_RPC_ENDPOINT` | SettleMint console → node → JSON-RPC endpoint                   |
| `SETTLEMINT_BLOCKCHAIN_NETWORK`                | SettleMint console → network unique name                        |
| `SETTLEMINT_BLOCKCHAIN_NETWORK_CHAIN_ID`       | Shown during deploy (e.g. `47536`)                              |
| `SETTLEMINT_THEGRAPH`                          | Your Graph middleware unique name (e.g. `gmw-fc08a`)            |
| `SETTLEMINT_BLOCKSCOUT`                        | Your Blockscout unique name (if deployed)                       |

> **Note**: Do not add `SETTLEMINT_ACCESS_TOKEN` to `.env`. The CLI uses your personal access token from `settlemint login` automatically.

### 4.3 Activate private key on node

In the SettleMint console → your application → your node → activate or create an **ECDSA P256 private key**.

## 5. Deploy Contracts

```bash
bunx settlemint scs hardhat deploy remote \
  -m ignition/modules/main.ts \
  --blockchain-node <your-node-name> \
  --accept-defaults
```

Confirm with `y` when prompted. This deploys 7 contracts:

- `ERC6551Registry` — core registry
- `ERC6551BatchRegistry` — batch account creation
- `TokenBoundAccount` — base TBA implementation
- `ERC1271TokenBoundAccount` — TBA with signature validation
- `ExampleNFT` — demo NFT
- `ExampleERC20` — demo ERC-20 token
- `ExampleUsage` — integration example

### 5.1 Verify Deployed Addresses

```bash
cat ignition/deployments/chain-*/deployed_addresses.json
```

All 7 contracts should appear.

## 6. Update Subgraph Config

Edit `subgraph/subgraph.config.json` with the deployed Registry and BatchRegistry addresses and your chain ID:

```json
{
  "output": "generated/scs.",
  "chain": "<YOUR_CHAIN_ID>",
  "datasources": [
    {
      "name": "ERC6551Registry",
      "address": "<REGISTRY_ADDRESS>",
      "startBlock": 0,
      "module": ["erc6551"]
    },
    {
      "name": "ERC6551BatchRegistry",
      "address": "<BATCH_REGISTRY_ADDRESS>",
      "startBlock": 0,
      "module": ["erc6551batch"]
    }
  ]
}
```

## 7. Build and Deploy Subgraph

```bash
forge build
bunx settlemint scs subgraph build
bunx settlemint scs subgraph deploy erc6651 --accept-defaults
```

## 8. Run the Demo Script

```bash
bunx settlemint scs hardhat script remote \
  --script scripts/createAccountExample.ts \
  --blockchain-node <your-node-name> \
  --accept-defaults
```

The script auto-detects contract addresses from `ignition/deployments/chain-*/deployed_addresses.json`.

### What the script does

| Step | Action                           | What it proves                                |
| ---- | -------------------------------- | --------------------------------------------- |
| 1    | Mint an NFT                      | NFT contract works                            |
| 2    | Compute TBA address              | Deterministic CREATE2 addressing              |
| 3    | Create TBA                       | Registry creates account at predicted address |
| 4    | Send ETH to TBA                  | TBA can receive native tokens                 |
| 5    | Execute ETH transfer from TBA    | NFT owner controls TBA                        |
| 6    | Check account state              | State increments on execution                 |
| 7    | Mint ERC-20 tokens               | ERC-20 contract works                         |
| 8    | Transfer ERC-20 to TBA           | TBA can hold ERC-20 tokens                    |
| 9    | Execute ERC-20 transfer from TBA | TBA can send ERC-20 tokens via `execute()`    |

## 9. Verify

### Subgraph

Open The Graph playground from the SettleMint console and run:

```graphql
{
  tokenBoundAccounts(
    first: 10
    orderBy: createdAtTimestamp
    orderDirection: desc
  ) {
    id
    tokenId
    owner {
      id
    }
    createdAtTimestamp
  }
}
```

### Blockscout

Open the Blockscout explorer from the SettleMint console. Search for the TBA address to see ETH and ERC-20 balances and transaction history.

## Troubleshooting

| Issue                                           | Solution                                                                     |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| `settlemint: command not found`                 | Run `bun install`                                                            |
| Deployment fails "already deployed"             | Delete `ignition/deployments/` and redeploy                                  |
| "does not have an ECDSA P256 private key"       | Activate ECDSA P256 key on your node in the SettleMint console               |
| "No application configured"                     | Create `.env` from `.env.example` — see step 4.2                             |
| "AAT not found"                                 | Remove `SETTLEMINT_ACCESS_TOKEN` from `.env` — the CLI uses your login token |
| Subgraph build fails                            | Run `forge build` first, verify addresses in `subgraph/subgraph.config.json` |
| Demo script "Could not find contract addresses" | Deploy contracts first (step 5)                                              |
| Graph query returns empty                       | Wait for subgraph to sync                                                    |
