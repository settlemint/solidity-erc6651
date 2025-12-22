# ERC-6551 Token Bound Accounts - Usage Guide

## What is ERC-6551?

**ERC-6551** introduces **Token Bound Accounts (TBAs)** - smart contract wallets that are owned and controlled by NFTs. Every NFT can have its own Ethereum account that can:

- Hold ETH, ERC-20 tokens, and other NFTs
- Execute transactions
- Interact with any smart contract
- Sign messages (with ERC-1271)

### The Key Insight

When you transfer an NFT, **everything in its TBA goes with it**. The NFT becomes a portable identity/inventory that carries all its assets.

```
┌─────────────────────────────────────────────────────────────┐
│                         NFT #1                              │
│                    (owned by Alice)                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Token Bound Account                      │  │
│  │                                                       │  │
│  │   💰 2.5 ETH                                         │  │
│  │   🪙 1000 USDC                                       │  │
│  │   🖼️ NFT Collection Items                            │  │
│  │   📜 DAO Voting Rights                               │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Transfer NFT #1 to Bob
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                         NFT #1                              │
│                     (owned by Bob)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Token Bound Account                      │  │
│  │           (Bob now controls everything)              │  │
│  │                                                       │  │
│  │   💰 2.5 ETH                                         │  │
│  │   🪙 1000 USDC                                       │  │
│  │   🖼️ NFT Collection Items                            │  │
│  │   📜 DAO Voting Rights                               │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Architecture

### Core Components

| Contract | Purpose |
|----------|---------|
| `ERC6551Registry` | Creates TBAs using CREATE2 for deterministic addresses |
| `ERC6551BatchRegistry` | Gas-optimized batch creation (58-66% savings) |
| `TokenBoundAccount` | Base account with execute capability |
| `ERC1271TokenBoundAccount` | Extended account with signature validation |

### How It Works

1. **Deterministic Addresses**: Account addresses are computed from `(implementation, salt, chainId, tokenContract, tokenId)`
2. **Minimal Proxies**: Each TBA is only 173 bytes (ERC-1167 proxy pattern)
3. **Immutable Binding**: Token info is encoded in the proxy bytecode
4. **Dynamic Ownership**: `owner()` queries the NFT contract in real-time

## Quick Start

### 1. Deploy the Contracts

```bash
# Using Hardhat Ignition
npx hardhat ignition deploy ignition/modules/main.ts --network localhost
```

### 2. Create a Token Bound Account

```solidity
// Get the registry and implementation addresses from deployment
ERC6551Registry registry = ERC6551Registry(REGISTRY_ADDRESS);
address implementation = IMPLEMENTATION_ADDRESS;

// Create an account for your NFT
address account = registry.createAccount(
    implementation,      // Account implementation
    bytes32(0),          // Salt (use 0 for default)
    block.chainid,       // Current chain
    NFT_CONTRACT,        // Your NFT contract
    TOKEN_ID             // Your token ID
);
```

### 3. Execute Transactions

```solidity
TokenBoundAccount tba = TokenBoundAccount(payable(account));

// Only the NFT owner can execute
tba.execute(
    recipient,           // Target address
    1 ether,             // Value to send
    "",                  // Calldata (empty for ETH transfer)
    0                    // Operation type (0 = CALL)
);
```

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
