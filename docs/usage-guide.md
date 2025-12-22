# ERC-6551 Token Bound Accounts - Usage Guide

## What is ERC-6551?

**ERC-6551** gives every NFT its own smart contract wallet. Think of it as a backpack attached to your NFT - it can hold ETH, tokens, other NFTs, and interact with any dApp.

**The magic**: When you transfer the NFT, the wallet and everything inside transfers with it.

```
┌────────────────────────────────────────┐
│              NFT #42                   │
│           (owned by Alice)             │
│  ┌──────────────────────────────────┐  │
│  │     Token Bound Account          │  │
│  │                                  │  │
│  │   💰 2.5 ETH                     │  │
│  │   🪙 1000 USDC                   │  │
│  │   🖼️ 3 other NFTs                │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
              │
              │  Alice transfers NFT to Bob
              ▼
┌────────────────────────────────────────┐
│              NFT #42                   │
│            (owned by Bob)              │
│  ┌──────────────────────────────────┐  │
│  │     Token Bound Account          │  │
│  │     (Bob controls it now)        │  │
│  │                                  │  │
│  │   💰 2.5 ETH                     │  │
│  │   🪙 1000 USDC                   │  │
│  │   🖼️ 3 other NFTs                │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

## What Can Be Tokenized as NFTs?

NFTs can represent **any digital or physical asset**. The NFT itself is a unique on-chain token that points to metadata (usually stored on IPFS or a server). ERC-6551 works with any NFT regardless of what it represents.

### Supported File Types

| Category | File Extensions | Use Cases |
|----------|-----------------|-----------|
| **Images** | `.jpg`, `.jpeg`, `.png`, `.gif`, `.svg`, `.webp`, `.bmp`, `.tiff` | Digital art, photographs, profile pictures, collectibles |
| **Video** | `.mp4`, `.avi`, `.mov`, `.webm`, `.mkv`, `.m4v` | Video art, movies, clips, animations |
| **Audio** | `.mp3`, `.wav`, `.flac`, `.aac`, `.ogg`, `.m4a` | Music, podcasts, sound effects, audio collectibles |
| **3D Models** | `.glb`, `.gltf`, `.obj`, `.fbx`, `.stl` | Metaverse assets, virtual real estate, game items |
| **Documents** | `.pdf`, `.doc`, `.docx`, `.txt`, `.md` | Certificates, licenses, legal documents, tickets |
| **Archives** | `.zip`, `.tar`, `.gz` | Software, datasets, bundles |

### Beyond Files: Real-World Assets (RWA)

NFTs can also represent assets that aren't files:

| Asset Type | Examples |
|------------|----------|
| **Physical Items** | Luxury goods, real estate deeds, art pieces, collectible cards |
| **Identity** | Membership cards, credentials, access passes, loyalty points |
| **Financial** | Bonds, invoices, royalty rights, fractional ownership |
| **Gaming** | Characters, weapons, skins, virtual land, in-game items |
| **Tickets** | Event tickets, boarding passes, reservations |

### How It Works with ERC-6551

```
┌─────────────────────────────────────────────────────────────┐
│                     NFT (ERC-721)                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Token ID: 42                                         │  │
│  │  Metadata URI: ipfs://Qm.../metadata.json            │  │
│  │                                                       │  │
│  │  {                                                    │  │
│  │    "name": "My Video NFT",                           │  │
│  │    "image": "ipfs://Qm.../thumbnail.jpg",            │  │
│  │    "animation_url": "ipfs://Qm.../video.mp4"         │  │
│  │  }                                                    │  │
│  └───────────────────────────────────────────────────────┘  │
│                            │                                │
│                            ▼                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           Token Bound Account (ERC-6551)              │  │
│  │                                                       │  │
│  │   Can hold: ETH, ERC-20 tokens, other NFTs           │  │
│  │   Can do: Execute transactions, sign messages        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Key point**: ERC-6551 doesn't care what the NFT represents - it gives ANY NFT its own wallet. Whether your NFT is a JPEG, a video, or a real estate deed, it can have a Token Bound Account.

---

## Quick Start

### 1. Install & Test

```bash
bun install && forge install
forge test
```

### 2. Deploy to SettleMint Platform

```bash
bunx settlemint login
bunx settlemint connect
bunx settlemint scs hardhat deploy remote --blockchain-node <your-node> -m ignition/modules/main.ts
```

### 3. Deploy Subgraph (Optional)

```bash
bunx settlemint scs subgraph build
bunx settlemint scs subgraph deploy <subgraph-name>
```

---

## End-to-End Demo (Show Your Boss in 5 Minutes)

After deploying, run the demo script to see everything working:

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy contracts
npx hardhat ignition deploy ignition/modules/main.ts --network localhost

# Terminal 3: Run demo
node demo.mjs
```

**What the demo does:**

```
=== ERC-6551 Token Bound Accounts Demo ===

1. Minting NFT...
   Minted NFT #0 to 0xf39Fd6e5...

2. Predicted TBA address: 0x1234...
   Code before creation: 0 bytes (not deployed)

3. Creating Token Bound Account...
   Gas used: 85000

4. TBA deployed! Bytecode: 173 bytes
   (Minimal proxy: 45 bytes + token data: 128 bytes)

5. TBA is bound to:
   Chain ID: 31337
   NFT Contract: 0x2279B7A0...
   Token ID: 0

6. TBA Owner: 0xf39Fd6e5...
   (Same as wallet that owns the NFT!)

7. Sending 1 ETH to TBA...
   TBA balance: 1 ETH

8. Executing: TBA sends 0.5 ETH to recipient...
   Gas used: 35000
   TBA balance after: 0.5 ETH

=== Key Takeaways ===
• NFT owner controls the TBA
• TBA can hold ETH/tokens and execute transactions
• If NFT is transferred, new owner controls TBA
```

---

## Manual Demo with Cast (CLI)

If you prefer command-line, here's the same flow using `cast`:

```bash
# Set contract addresses (replace with your deployed addresses)
export REGISTRY=0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
export IMPL=0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
export NFT=0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 1. Mint an NFT
cast send $NFT "mint(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --private-key $PRIVATE_KEY

# 2. Get predicted TBA address for token #0
cast call $REGISTRY "account(address,bytes32,uint256,address,uint256)" \
  $IMPL 0x0000000000000000000000000000000000000000000000000000000000000000 31337 $NFT 0

# 3. Create the TBA
cast send $REGISTRY "createAccount(address,bytes32,uint256,address,uint256)" \
  $IMPL 0x0000000000000000000000000000000000000000000000000000000000000000 31337 $NFT 0 \
  --private-key $PRIVATE_KEY

# 4. Send 1 ETH to TBA
export TBA=<address-from-step-2>
cast send $TBA --value 1ether --private-key $PRIVATE_KEY

# 5. Check TBA balance
cast balance $TBA

# 6. Execute from TBA (send 0.5 ETH)
cast send $TBA "execute(address,uint256,bytes,uint8)" \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 500000000000000000 0x 0 \
  --private-key $PRIVATE_KEY

# 7. Check owner (should match NFT owner)
cast call $TBA "owner()"
```

---

## Query the Subgraph

After deploying the subgraph, you can query all Token Bound Accounts:

### Get All Token Bound Accounts

```graphql
{
  tokenBoundAccounts(first: 10, orderBy: createdAtTimestamp, orderDirection: desc) {
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

### Get Accounts for a Specific NFT Collection

```graphql
{
  tokenContract(id: "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6") {
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

### Get Recent Account Creations

```graphql
{
  accountCreatedEvents(first: 20, orderBy: timestamp, orderDirection: desc) {
    id
    timestamp
    account {
      id
      tokenId
    }
    from {
      id
    }
    tokenContract
  }
}
```

### Get Batch Creations

```graphql
{
  batchCreations(first: 10, orderBy: timestamp, orderDirection: desc) {
    id
    totalInBatch
    newlyCreated
    tokenContract
    timestamp
    accounts
  }
}
```

### Query Using curl

```bash
# Replace with your subgraph endpoint
SUBGRAPH_URL="https://your-subgraph.settlemint.com/subgraphs/name/erc6551"

curl -X POST $SUBGRAPH_URL \
  -H "Content-Type: application/json" \
  -d '{"query": "{ tokenBoundAccounts(first: 5) { id tokenId owner { id } } }"}'
```

---

## Integration Examples

### JavaScript/TypeScript (viem)

```typescript
import { createPublicClient, http, parseAbi } from 'viem';

const client = createPublicClient({
  chain: yourChain,
  transport: http('YOUR_RPC_URL')
});

const registryAbi = parseAbi([
  'function createAccount(address,bytes32,uint256,address,uint256) returns (address)',
  'function account(address,bytes32,uint256,address,uint256) view returns (address)',
]);

// Compute address
const tbaAddress = await client.readContract({
  address: REGISTRY,
  abi: registryAbi,
  functionName: 'account',
  args: [implementation, salt, chainId, nftContract, tokenId]
});

// Check if deployed
const code = await client.getCode({ address: tbaAddress });
const isDeployed = code && code.length > 2;
```

### Ethers.js

```javascript
const { ethers } = require('ethers');

const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const wallet = new ethers.Wallet(privateKey, provider);

const registry = new ethers.Contract(REGISTRY, [
  'function createAccount(address,bytes32,uint256,address,uint256) returns (address)',
  'function account(address,bytes32,uint256,address,uint256) view returns (address)',
], wallet);

// Create TBA
const tx = await registry.createAccount(impl, salt, chainId, nft, tokenId);
await tx.wait();
```

## Contracts Overview

| Contract | What it does |
|----------|--------------|
| `ERC6551Registry` | Creates accounts for NFTs |
| `ERC6551BatchRegistry` | Creates many accounts at once (saves gas) |
| `TokenBoundAccount` | The wallet itself - holds assets, executes transactions |
| `ERC1271TokenBoundAccount` | Same as above + can verify signatures |
| `ExampleNFT` | Sample NFT for testing |
| `ExampleUsage` | Helper contract showing integration patterns |

## Detailed Usage

### Computing Addresses Before Creation

You can know a TBA's address before it exists - useful for sending assets to accounts that haven't been created yet.

```solidity
// Compute address without deploying
address futureAccount = registry.account(
    implementation,
    bytes32(0),           // salt
    block.chainid,
    nftContract,
    tokenId
);

// You can send ETH/tokens here even before the account is created!
// When the account is eventually created, it will have access to these funds.
```

### Creating Multiple Accounts

Each NFT can have **multiple** TBAs using different salts:

```solidity
// Default account (salt = 0)
address account1 = registry.createAccount(impl, bytes32(0), chainId, nft, tokenId);

// Secondary account (salt = 1)
address account2 = registry.createAccount(impl, bytes32(uint256(1)), chainId, nft, tokenId);

// Both accounts are controlled by the same NFT owner
```

### Batch Account Creation

For NFT collections, use the batch registry to save 58-66% on gas:

```solidity
ERC6551BatchRegistry batchRegistry = ERC6551BatchRegistry(BATCH_REGISTRY);

uint256[] memory tokenIds = new uint256[](100);
for (uint256 i = 0; i < 100; i++) {
    tokenIds[i] = i + 1;
}

// Create 100 accounts in one transaction
address[] memory accounts = batchRegistry.batchCreateAccounts(
    implementation,
    bytes32(0),
    block.chainid,
    nftContract,
    tokenIds
);
```

### Checking Account Status

```solidity
// Check if account exists
bool exists = account.code.length > 0;

// Get token info
(uint256 chainId, address tokenContract, uint256 tokenId) = tba.token();

// Get current owner (queries NFT contract)
address owner = tba.owner();

// Get state (increments on each execute)
uint256 state = tba.state();

// Check if address is valid signer
bytes4 result = tba.isValidSigner(someAddress, "");
// Returns 0x523e3260 if valid, 0x00000000 if invalid
```

### Execute Operations

The `execute()` function supports 4 operation types:

```solidity
// Operation 0: CALL - Standard external call
tba.execute(target, value, data, 0);

// Operation 1: DELEGATECALL - Execute in account's context
tba.execute(target, 0, data, 1);

// Operation 2: CREATE - Deploy new contract
bytes memory result = tba.execute(address(0), 0, creationCode, 2);
address deployed = abi.decode(result, (address));

// Operation 3: CREATE2 - Deploy with deterministic address
bytes memory saltAndCode = abi.encodePacked(salt, creationCode);
bytes memory result = tba.execute(address(0), 0, saltAndCode, 3);
address deployed = abi.decode(result, (address));
```

### ERC-1271 Signature Validation

The `ERC1271TokenBoundAccount` supports off-chain signature validation:

```solidity
ERC1271TokenBoundAccount account = ERC1271TokenBoundAccount(payable(accountAddress));

// Hash to verify
bytes32 hash = keccak256("message to sign");

// Signature from NFT owner's EOA
bytes memory signature = /* owner's signature */;

// Verify - returns 0x1626ba7e if valid
bytes4 result = account.isValidSignature(hash, signature);

if (result == 0x1626ba7e) {
    // Signature is valid - NFT owner signed this
}
```

## Common Patterns

### Pattern 1: Game Inventory

```solidity
// Character NFT owns its inventory
contract GameCharacter {
    IERC6551Registry registry;
    address implementation;

    function getInventoryAccount(uint256 characterId) public view returns (address) {
        return registry.account(implementation, 0, block.chainid, address(this), characterId);
    }

    function equipItem(uint256 characterId, address itemNFT, uint256 itemId) external {
        // Transfer item to character's inventory
        IERC721(itemNFT).transferFrom(msg.sender, getInventoryAccount(characterId), itemId);
    }
}
```

### Pattern 2: DAO Membership with Bundled Assets

```solidity
// Membership NFT that holds governance tokens
contract DAOMembership {
    function claimGovernanceTokens(uint256 membershipId) external {
        address memberAccount = registry.account(impl, 0, block.chainid, address(this), membershipId);

        // Mint governance tokens to the membership's account
        governanceToken.mint(memberAccount, 1000e18);
    }
}
```

### Pattern 3: Cross-Chain Account Reference

```solidity
// Create account that references token on another chain
address l2Account = registry.createAccount(
    implementation,
    bytes32(0),
    10,              // Optimism chain ID
    l1NftContract,   // L1 NFT contract
    tokenId
);

// Note: owner() returns address(0) since NFT is on different chain
// Useful for receiving assets that will be claimable after bridging
```

### Pattern 4: Signature-Based Meta-Transactions

```solidity
contract TBARelayer {
    function executeWithSignature(
        address account,
        address target,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external {
        // Verify signature
        bytes32 hash = keccak256(abi.encode(target, value, data, nonce++));
        require(
            IERC1271(account).isValidSignature(hash, signature) == 0x1626ba7e,
            "Invalid signature"
        );

        // Execute (caller must be owner or have approval)
        IERC6551Executable(account).execute(target, value, data, 0);
    }
}
```

## Key Behaviors

### Ownership Follows NFT

```solidity
// Alice owns NFT #1 and its account
assertEq(tba.owner(), alice);

// Transfer NFT to Bob
nft.transferFrom(alice, bob, 1);

// Now Bob owns the account and all its contents
assertEq(tba.owner(), bob);

// Alice can no longer execute
vm.prank(alice);
vm.expectRevert(TokenBoundAccount.NotAuthorized.selector);
tba.execute(target, 0, "", 0);

// Bob can execute
vm.prank(bob);
tba.execute(target, 0, "", 0); // Works!
```

### Idempotent Creation

```solidity
// Creating an existing account returns the same address
address addr1 = registry.createAccount(impl, salt, chainId, nft, tokenId);
address addr2 = registry.createAccount(impl, salt, chainId, nft, tokenId);

assertEq(addr1, addr2); // Same address, no revert
```

### State Tracking

```solidity
// State increments on each successful execute
uint256 state0 = tba.state(); // 0

tba.execute(target, 0, "", 0);
uint256 state1 = tba.state(); // 1

tba.execute(target, 0, "", 0);
uint256 state2 = tba.state(); // 2

// Useful for detecting account activity changes
```

## Gas Benchmarks

| Operation | Gas Cost |
|-----------|----------|
| Single account creation | ~85,000 |
| Batch create (per account) | ~77,000 |
| Execute (ETH transfer) | ~35,000 |
| Compute address (view) | ~2,000 |

Batch creation saves **58-66%** compared to individual creation due to reduced transaction overhead.

## Interface Reference

### IERC6551Account

```solidity
interface IERC6551Account {
    // Returns (chainId, tokenContract, tokenId)
    function token() external view returns (uint256, address, uint256);

    // Returns current NFT owner (address(0) if cross-chain)
    function owner() external view returns (address);

    // Returns state counter
    function state() external view returns (uint256);

    // Validates if address is authorized signer
    function isValidSigner(address signer, bytes calldata context)
        external view returns (bytes4);
}
```

### IERC6551Executable

```solidity
interface IERC6551Executable {
    // Execute transaction (0=CALL, 1=DELEGATECALL, 2=CREATE, 3=CREATE2)
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external payable returns (bytes memory);
}
```

### IERC6551Registry

```solidity
interface IERC6551Registry {
    // Compute account address
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address);

    // Create account
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address);
}
```

## Security Considerations

1. **DELEGATECALL Risk**: Operation type 1 allows modifying account storage - use with caution
2. **Cross-Chain**: `owner()` returns `address(0)` when NFT is on different chain
3. **Authorization**: Always verify `owner()` before trusting account operations
4. **Reentrancy**: The execute function includes a state increment before external calls
5. **Approval Patterns**: Consider implementing allowance/approval for delegated execution

## Further Reading

- [ERC-6551 Specification](https://eips.ethereum.org/EIPS/eip-6551)
- [ERC-1167 Minimal Proxy](https://eips.ethereum.org/EIPS/eip-1167)
- [ERC-1271 Signature Validation](https://eips.ethereum.org/EIPS/eip-1271)
