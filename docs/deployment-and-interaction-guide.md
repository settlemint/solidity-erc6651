# ERC-6551 Token Bound Accounts: Deployment & Interaction Guide

This guide walks you through deploying the ERC-6551 contracts on-chain and interacting with them, including creating Token Bound Accounts (TBAs), sending tokens to and from those accounts, and linking accounts to NFTs.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Deploy the Contracts](#3-deploy-the-contracts)
4. [Verify the Deployment](#4-verify-the-deployment)
5. [Linking an ERC-6551 Account to an NFT](#5-linking-an-erc-6551-account-to-an-nft)
6. [Sending Assets to a Token Bound Account](#6-sending-assets-to-a-token-bound-account)
7. [Sending Assets from a Token Bound Account](#7-sending-assets-from-a-token-bound-account)
8. [Full Walkthrough: The Demo Script](#8-full-walkthrough-the-demo-script)
9. [Querying Account Data (Subgraph)](#9-querying-account-data-subgraph)
10. [FAQ & Troubleshooting](#10-faq--troubleshooting)

---

## 1. Overview

ERC-6551 gives every NFT its own smart contract wallet (called a **Token Bound Account** or **TBA**). The TBA can hold ETH, ERC-20 tokens, other NFTs, and execute arbitrary transactions. When the NFT is transferred to a new owner, control of the TBA transfers automatically.

### Deployed Contracts

| Contract                     | Purpose                                            |
| ---------------------------- | -------------------------------------------------- |
| **ERC6551Registry**          | Central registry that creates TBAs for NFTs        |
| **ERC6551BatchRegistry**     | Gas-optimized batch creation of multiple TBAs      |
| **TokenBoundAccount**        | The TBA implementation (the wallet itself)         |
| **ERC1271TokenBoundAccount** | Extended TBA with ERC-1271 signature verification  |
| **ExampleNFT**               | Demo ERC-721 NFT for testing                       |
| **ExampleERC20**             | Demo ERC-20 token for testing                      |
| **ExampleUsage**             | Helper contract demonstrating integration patterns |

### How It Works

```
1. You own an NFT (ERC-721)
2. You call the Registry to create a Token Bound Account for that NFT
3. The TBA is a smart contract wallet at a deterministic address
4. As the NFT owner, you can send ETH/tokens TO the TBA
5. As the NFT owner, you can execute transactions FROM the TBA
6. If you transfer the NFT, the new owner gains control of the TBA
```

---

## 2. Prerequisites

- **Node.js** >= 20
- **bun** package manager
- **Foundry** (`forge`) for Solidity compilation
- **SettleMint account** with an active workspace, application, and blockchain node

Install dependencies:

```bash
bun install
forge install
```

Log in and connect to SettleMint:

```bash
bunx settlemint login
bunx settlemint connect
```

Create your `.env` file from the template:

```bash
cp .env.example .env
```

Fill in the values from the SettleMint console (workspace, application, node name, RPC endpoint, etc.). See the [end-to-end deployment guide](settlemint-e2e-deployment.md) for detailed `.env` configuration.

Make sure your blockchain node has an **ECDSA P256 private key** activated in the SettleMint console.

---

## 3. Deploy the Contracts

Deploy all contracts to your SettleMint blockchain node:

```bash
bunx settlemint scs hardhat deploy remote \
  -m ignition/modules/main.ts \
  --blockchain-node <your-node-name> \
  --accept-defaults
```

Confirm with `y` when prompted. This deploys all 7 contracts in a single deployment.

---

## 4. Verify the Deployment

After deployment, verify that all contract addresses were saved:

```bash
cat ignition/deployments/chain-*/deployed_addresses.json
```

You should see output like:

```json
{
  "ERC6551Module#ERC6551Registry": "0x...",
  "ERC6551Module#ERC6551BatchRegistry": "0x...",
  "ERC6551Module#TokenBoundAccount": "0x...",
  "ERC6551Module#ERC1271TokenBoundAccount": "0x...",
  "ERC6551Module#ExampleNFT": "0x...",
  "ERC6551Module#ExampleERC20": "0x...",
  "ERC6551Module#ExampleUsage": "0x..."
}
```

Save these addresses. The demo script auto-detects them, but you will need them if you interact with the contracts manually.

---

## 5. Linking an ERC-6551 Account to an NFT

"Linking" an ERC-6551 account to an NFT is the process of **creating a Token Bound Account** for a specific NFT. This is done through the **ERC6551Registry** contract.

### How the Account is Defined

A Token Bound Account is a **minimal proxy contract** (ERC-1167) deployed by the Registry. The NFT's identity is encoded directly into the deployed bytecode, which makes the binding permanent and tamper-proof.

When the Registry deploys a TBA, the bytecode layout is:

```
┌──────────────────────────────────────────────────────────────┐
│  EIP-1167 Proxy Header    (10 bytes)  - delegates to impl   │
│  Implementation Address   (20 bytes)  - TokenBoundAccount   │
│  EIP-1167 Proxy Footer    (15 bytes)  - completes proxy     │
│  Salt                     (32 bytes)  - unique salt value    │
│  Chain ID                 (32 bytes)  - blockchain ID        │
│  Token Contract Address   (32 bytes)  - NFT contract addr   │
│  Token ID                 (32 bytes)  - specific NFT ID      │
└──────────────────────────────────────────────────────────────┘
Total: 173 bytes of deployed code
```

The TBA reads its own bytecode to know which NFT it belongs to. This data is immutable -- it cannot be changed after deployment.

### Contract Functions: Inputs and Outputs

#### `ERC6551Registry.createAccount()` -- Creates and links a TBA to an NFT

```solidity
function createAccount(
    address implementation,   // IN: address of TokenBoundAccount contract
    bytes32 salt,             // IN: unique salt (use 0x0 for default)
    uint256 chainId,          // IN: chain ID where the NFT exists
    address tokenContract,    // IN: the ERC-721 NFT contract address
    uint256 tokenId           // IN: the specific NFT token ID
) external returns (
    address accountAddress    // OUT: the deployed TBA address
);
```

- Emits: `ERC6551AccountCreated(accountAddress, implementation, salt, chainId, tokenContract, tokenId)`
- If the account already exists, returns the existing address (does not revert).

#### `ERC6551Registry.account()` -- Computes a TBA address without deploying

```solidity
function account(
    address implementation,   // IN: address of TokenBoundAccount contract
    bytes32 salt,             // IN: unique salt
    uint256 chainId,          // IN: chain ID
    address tokenContract,    // IN: NFT contract address
    uint256 tokenId           // IN: NFT token ID
) external view returns (
    address                   // OUT: the deterministic TBA address
);
```

- This is a **view** function (no gas cost, no state change).
- Returns the same address regardless of whether the account has been deployed yet.

#### `TokenBoundAccount.token()` -- Reads which NFT the account is bound to

```solidity
function token() public view returns (
    uint256 chainId,          // OUT: chain ID of the bound NFT
    address tokenContract,    // OUT: NFT contract address
    uint256 tokenId           // OUT: NFT token ID
);
```

#### `TokenBoundAccount.owner()` -- Returns the current controller

```solidity
function owner() public view returns (
    address                   // OUT: the wallet address that owns the NFT
                              //      (address(0) if NFT is on a different chain)
);
```

#### `TokenBoundAccount.execute()` -- Executes a transaction from the TBA

```solidity
function execute(
    address to,               // IN: target address
    uint256 value,            // IN: ETH value to send
    bytes calldata data,      // IN: encoded function call (or 0x for plain ETH)
    uint8 operation           // IN: 0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2
) external payable returns (
    bytes memory result       // OUT: return data from the call
);
```

- Only callable by the current NFT owner (reverts with `NotAuthorized()` otherwise).
- Emits: `Executed(to, value, data, operation)`

### How the TBA Knows Which NFT It Belongs To (and Who the Owner Is)

A common question: `createAccount()` does not verify NFT ownership -- anyone can call it for any NFT. So how does the system know who controls the account?

The answer is that **identity** and **authorization** are handled at different times:

**At creation time**, the Registry bakes the NFT's `tokenContract` and `tokenId` into the TBA's bytecode. That is how the account permanently knows which NFT it is linked to.

**At execution time**, when someone calls `execute()`, the TBA performs a live ownership check:

```
execute() called by msg.sender
    │
    ▼
_isValidSigner(msg.sender)
    │
    ▼
owner()
    │  reads tokenContract + tokenId from its own bytecode via token()
    │  then calls the NFT contract:
    ▼
IERC721(tokenContract).ownerOf(tokenId)   ← "who owns this NFT right now?"
    │
    ▼
if msg.sender == ownerOf result  →  allow
if msg.sender != ownerOf result  →  revert NotAuthorized()
```

The key insight: **ownership is always queried live from the NFT contract**. The TBA does not store the owner's address. Instead, every time `execute()` is called, the TBA:

1. Calls `token()` to read the NFT contract address and token ID from its own bytecode
2. Calls `ownerOf(tokenId)` on the NFT contract to get the current holder
3. Compares the result to `msg.sender`

This means:

- **If Alice transfers the NFT to Bob**, Bob immediately controls the TBA -- no update to the TBA is needed.
- **All assets inside the TBA** (ETH, ERC-20 tokens, other NFTs) transfer with the NFT automatically.
- **The previous owner** (Alice) is immediately locked out and can no longer call `execute()`.

### Step 1: Mint an NFT

First, you need an NFT. Using the deployed `ExampleNFT` contract:

```typescript
// Mint an NFT to your wallet
const mintTx = await nft.write.mint([yourWalletAddress]);
await publicClient.waitForTransactionReceipt({ hash: mintTx });

// The minted token ID is returned by nextTokenId - 1
const tokenId = (await nft.read.nextTokenId()) - 1n;
```

### Step 2: Compute the TBA Address (Optional)

Before creating the account, you can compute its future address. This is useful because the address is **deterministic** -- you can know it in advance and even send assets to it before it is deployed.

```typescript
import { zeroHash } from "viem";

const accountAddress = await registry.read.account([
  IMPLEMENTATION_ADDRESS, // TokenBoundAccount address
  zeroHash, // salt (use 0x0 for the default account)
  chainId, // your blockchain's chain ID
  NFT_ADDRESS, // the NFT contract address
  tokenId, // the specific token ID
]);
```

The five parameters that uniquely identify a TBA:

| Parameter        | Description                                                                                                           |
| ---------------- | --------------------------------------------------------------------------------------------------------------------- |
| `implementation` | Address of the TokenBoundAccount contract                                                                             |
| `salt`           | A bytes32 value (use `0x0` for the default account; use different salts to create multiple accounts for the same NFT) |
| `chainId`        | The chain ID where the NFT lives                                                                                      |
| `tokenContract`  | The ERC-721 NFT contract address                                                                                      |
| `tokenId`        | The specific NFT token ID                                                                                             |

### Step 3: Create the Token Bound Account

Call `createAccount` on the Registry to deploy the TBA:

```typescript
const createTx = await registry.write.createAccount([
  IMPLEMENTATION_ADDRESS,
  zeroHash,
  chainId,
  NFT_ADDRESS,
  tokenId,
]);
const receipt = await publicClient.waitForTransactionReceipt({
  hash: createTx,
});
```

The TBA is now deployed at the predicted address. It is permanently bound to that specific NFT.

### Verify the Link

You can confirm the TBA is bound to the correct NFT:

```typescript
const account = await hre.viem.getContractAt(
  "TokenBoundAccount",
  accountAddress,
);

// Returns the chain ID, NFT contract, and token ID this account is bound to
const [tokenChainId, tokenContract, boundTokenId] = await account.read.token();

// Returns the current owner (the wallet that owns the NFT)
const owner = await account.read.owner();
```

### Key Points

- **One function call** (`createAccount`) links an NFT to its TBA.
- The link is **permanent and immutable** -- the TBA is always bound to that specific NFT.
- **Ownership is dynamic** -- whoever currently owns the NFT controls the TBA.
- Creating an already-existing account is safe -- it returns the existing address without reverting.
- You can create **multiple TBAs** for the same NFT by using different `salt` values.

---

## 6. Sending Assets to a Token Bound Account

A TBA is a regular smart contract address. You can send assets to it the same way you send to any other address.

### Send ETH (Native Token)

```typescript
// Send 0.01 ETH to the TBA
const sendTx = await walletClient.sendTransaction({
  to: accountAddress,
  value: parseEther("0.01"),
});
await publicClient.waitForTransactionReceipt({ hash: sendTx });

// Check the balance
const balance = await publicClient.getBalance({ address: accountAddress });
```

### Send ERC-20 Tokens

```typescript
// Standard ERC-20 transfer to the TBA address
const transferTx = await erc20.write.transfer([
  accountAddress,
  parseUnits("100", 18), // 100 tokens
]);
await publicClient.waitForTransactionReceipt({ hash: transferTx });

// Check the TBA's ERC-20 balance
const tbaBalance = await erc20.read.balanceOf([accountAddress]);
```

### Send NFTs

```typescript
// Transfer an NFT to the TBA (the TBA can hold other NFTs)
const transferNftTx = await otherNft.write.transferFrom([
  yourWalletAddress,
  accountAddress,
  otherTokenId,
]);
await publicClient.waitForTransactionReceipt({ hash: transferNftTx });
```

### Pre-funding Before Creation

Because TBA addresses are deterministic, you can compute the address and send assets to it **before** the account is even created. When the account is eventually deployed, it will have access to those funds.

```typescript
// Compute the address (account doesn't exist yet)
const futureAddress = await registry.read.account([
  impl,
  salt,
  chainId,
  nft,
  tokenId,
]);

// Send ETH to the future address
await walletClient.sendTransaction({
  to: futureAddress,
  value: parseEther("1"),
});

// Later, create the account -- it now has 1 ETH
await registry.write.createAccount([impl, salt, chainId, nft, tokenId]);
```

---

## 7. Sending Assets from a Token Bound Account

To send assets **from** a TBA, the NFT owner calls the `execute()` function on the TBA contract. The TBA acts as a smart wallet -- the NFT owner instructs it what to do.

### Send ETH from the TBA

```typescript
// The NFT owner calls execute() to send ETH from the TBA
const executeTx = await account.write.execute([
  recipientAddress, // to: where to send
  parseEther("0.005"), // value: amount of ETH
  "0x", // data: empty for a simple ETH transfer
  0, // operation: 0 = CALL
]);
await publicClient.waitForTransactionReceipt({ hash: executeTx });
```

### Send ERC-20 Tokens from the TBA

To transfer ERC-20 tokens from the TBA, you encode the ERC-20 `transfer()` call as the `data` parameter:

```typescript
import { encodeFunctionData, parseUnits } from "viem";

// Encode the ERC-20 transfer calldata
const transferCalldata = encodeFunctionData({
  abi: [
    {
      name: "transfer",
      type: "function",
      inputs: [
        { name: "to", type: "address" },
        { name: "amount", type: "uint256" },
      ],
      outputs: [{ name: "", type: "bool" }],
    },
  ],
  functionName: "transfer",
  args: [recipientAddress, parseUnits("25", 18)],
});

// Execute the ERC-20 transfer through the TBA
const executeTx = await account.write.execute([
  ERC20_ADDRESS, // to: the ERC-20 contract (not the recipient!)
  0n, // value: no ETH needed
  transferCalldata, // data: the encoded transfer call
  0, // operation: 0 = CALL
]);
await publicClient.waitForTransactionReceipt({ hash: executeTx });
```

### Send NFTs from the TBA

Same pattern -- encode the NFT transfer call:

```typescript
const transferNftCalldata = encodeFunctionData({
  abi: [
    {
      name: "transferFrom",
      type: "function",
      inputs: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "tokenId", type: "uint256" },
      ],
      outputs: [],
    },
  ],
  functionName: "transferFrom",
  args: [accountAddress, recipientAddress, nftTokenId],
});

const executeTx = await account.write.execute([
  OTHER_NFT_ADDRESS,
  0n,
  transferNftCalldata,
  0,
]);
```

### Authorization

Only the **current owner of the NFT** can call `execute()`. If anyone else tries, the transaction reverts with `NotAuthorized()`.

```
NFT Owner (your wallet)
    |
    | calls execute()
    v
Token Bound Account
    |
    | forwards the call
    v
Target Contract (ERC-20, NFT, or any contract)
```

---

## 8. Full Walkthrough: The Demo Script

The included demo script (`scripts/createAccountExample.ts`) performs all of the above operations in sequence. It auto-detects contract addresses from the deployment artifacts.

### Run the Demo

**On SettleMint:**

```bash
bunx settlemint scs hardhat script remote \
  --script scripts/createAccountExample.ts \
  --blockchain-node <your-node-name> \
  --accept-defaults
```

**On Local Anvil:**

```bash
# Terminal 1
anvil

# Terminal 2
npx hardhat ignition deploy ignition/modules/main.ts --network localhost
npx hardhat run scripts/createAccountExample.ts --network localhost
```

### What the Script Does (Step by Step)

| Step | Action                                            | What It Proves                                |
| ---- | ------------------------------------------------- | --------------------------------------------- |
| 1    | Mint an NFT to your wallet                        | NFT contract is working                       |
| 2    | Compute the TBA address                           | Deterministic CREATE2 addressing works        |
| 3    | Create the Token Bound Account                    | Registry deploys TBA at the predicted address |
| 4    | Send 0.01 ETH to the TBA                          | TBA can receive native tokens                 |
| 5    | Execute ETH transfer from the TBA                 | NFT owner controls the TBA wallet             |
| 6    | Check account state                               | State increments on each execution            |
| 7    | Mint 1,000 ERC-20 tokens to your wallet           | ERC-20 contract is working                    |
| 8    | Transfer 100 ERC-20 tokens to the TBA             | TBA can receive ERC-20 tokens                 |
| 9    | Execute ERC-20 transfer of 25 tokens from the TBA | TBA can send ERC-20 tokens via `execute()`    |

### Expected Output

```
=== ERC-6551 Token Bound Account Example ===

Using account: 0xf39Fd6e5...

Contract Addresses:
  Registry: 0xa513E6E4...
  Implementation: 0x8A791620...
  NFT: 0x2279B7A0...
  ERC20: 0x610178dA...

1. Minting NFT...
   Minted token ID: 1

2. Computing account address...
   Predicted account address: 0x1234...

3. Creating token-bound account...
   Transaction hash: 0x...
   Gas used: 85000
   Account created successfully!
   Token info - Chain: 31337 Contract: 0x2279B7A0... ID: 1

4. Sending ETH to account...
   Account balance: 10000000000000000 wei

5. Executing transaction through account...
   Execution hash: 0x...
   Final account balance: 5000000000000000 wei

6. Checking account state...
   Account state: 1 (increments on each execution)
   Account owner: 0xf39Fd6e5...

7. Minting ERC-20 tokens to owner...
   Owner ERC-20 balance: 1000000000000000000000

8. Transferring ERC-20 tokens to TBA...
   TBA ERC-20 balance: 100000000000000000000

9. Executing ERC-20 transfer from TBA...
   TBA ERC-20 balance after: 75000000000000000000
   Owner ERC-20 balance after: 925000000000000000000

=== Example Complete ===
```

---

## 9. Querying Account Data (Subgraph)

After deploying the subgraph (see [deployment guide](settlemint-e2e-deployment.md), steps 6-7), you can query TBA data using GraphQL.

### List All Token Bound Accounts

```graphql
{
  tokenBoundAccounts(
    first: 10
    orderBy: createdAtTimestamp
    orderDirection: desc
  ) {
    id
    tokenContract {
      id
    }
    tokenId
    chainId
    owner {
      id
    }
    createdAtTimestamp
  }
}
```

### Find Accounts for a Specific NFT Collection

```graphql
{
  tokenContract(id: "0x<your-nft-contract-address>") {
    id
    accountCount
    accounts(first: 100) {
      id
      tokenId
      owner {
        id
      }
    }
  }
}
```

### Query via curl

```bash
SUBGRAPH_URL="https://your-subgraph.settlemint.com/subgraphs/name/erc6651"

curl -X POST $SUBGRAPH_URL \
  -H "Content-Type: application/json" \
  -d '{"query": "{ tokenBoundAccounts(first: 5) { id tokenId owner { id } } }"}'
```

---

## 10. FAQ & Troubleshooting

### How is the TBA linked to the NFT?

The `createAccount()` function on the Registry deploys a minimal proxy contract with the NFT's chain ID, contract address, and token ID encoded directly into its bytecode. This binding is permanent. The TBA's `token()` function reads this data to identify which NFT it is bound to, and `owner()` queries the NFT contract to determine who currently owns that NFT.

### Can one NFT have multiple TBAs?

Yes. Use different `salt` values when calling `createAccount()`. Each unique combination of (implementation, salt, chainId, tokenContract, tokenId) produces a different TBA address.

### What happens when the NFT is transferred?

The new NFT owner automatically gains control of the TBA. The previous owner can no longer call `execute()`. All assets inside the TBA stay in place -- they transfer with the NFT.

### Can I send assets to a TBA before it is created?

Yes. Because TBA addresses are deterministic (computed via CREATE2), you can send ETH, ERC-20 tokens, or NFTs to the address before calling `createAccount()`. Once the account is deployed, it will have access to those funds.

### Why does `execute()` need encoded calldata for ERC-20 transfers?

The TBA acts as a generic smart wallet. To transfer ERC-20 tokens, the TBA needs to call `transfer()` on the ERC-20 contract. The `execute()` function takes the target contract address and the ABI-encoded function call as parameters, then forwards that call.

### Common Errors

| Error                                     | Cause                                        | Solution                                               |
| ----------------------------------------- | -------------------------------------------- | ------------------------------------------------------ |
| `NotAuthorized()`                         | Caller is not the NFT owner                  | Only the wallet that owns the NFT can call `execute()` |
| `AccountCreationFailed()`                 | CREATE2 deployment failed                    | Check that the implementation address is correct       |
| `Could not find contract addresses`       | Demo script cannot find deployment artifacts | Deploy contracts first (step 3)                        |
| `does not have an ECDSA P256 private key` | Node key not activated                       | Activate ECDSA P256 key in the SettleMint console      |
| `already deployed`                        | Contracts were previously deployed           | Delete `ignition/deployments/` and redeploy            |

### Gas Costs

| Operation                      | Approximate Gas |
| ------------------------------ | --------------- |
| Create a single TBA            | ~85,000         |
| Batch create (per account)     | ~77,000         |
| Execute (ETH transfer)         | ~35,000         |
| Compute address (view, no gas) | ~2,000          |
