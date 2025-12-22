import { createPublicClient, createWalletClient, http, parseAbi } from 'viem';
import { anvil } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

// Use Anvil default private key
const account = privateKeyToAccount('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');

const publicClient = createPublicClient({
  chain: anvil,
  transport: http('http://127.0.0.1:8545')
});

const walletClient = createWalletClient({
  account,
  chain: anvil,
  transport: http('http://127.0.0.1:8545')
});

const REGISTRY = '0xa513E6E4b8f2a923D98304ec87F64353C4D5C853';
const IMPL = '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318';
const NFT = '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6';

const registryAbi = parseAbi([
  'function createAccount(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId) external returns (address)',
  'function account(address implementation, bytes32 salt, uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address)',
]);

const nftAbi = parseAbi([
  'function mint(address to) external returns (uint256)',
  'function ownerOf(uint256 tokenId) external view returns (address)'
]);

const accountAbi = parseAbi([
  'function token() public view returns (uint256 chainId, address tokenContract, uint256 tokenId)',
  'function owner() public view returns (address)',
  'function execute(address to, uint256 value, bytes calldata data, uint8 operation) external payable returns (bytes memory)'
]);

async function main() {
  console.log('=== ERC-6551 Token Bound Accounts Demo ===\n');
  
  // 1. Mint an NFT
  console.log('1. Minting NFT...');
  const mintHash = await walletClient.writeContract({
    address: NFT,
    abi: nftAbi,
    functionName: 'mint',
    args: [account.address]
  });
  await publicClient.waitForTransactionReceipt({ hash: mintHash });
  
  // Find the tokenId by checking ownership
  let tokenId = 0n;
  for (let i = 0n; i < 10n; i++) {
    try {
      const owner = await publicClient.readContract({ address: NFT, abi: nftAbi, functionName: 'ownerOf', args: [i] });
      if (owner.toLowerCase() === account.address.toLowerCase()) {
        tokenId = i;
        break;
      }
    } catch {}
  }
  
  console.log(`   Minted NFT #${tokenId} to ${account.address.slice(0,10)}...\n`);

  // 2. Compute TBA address (before creation)
  const chainId = 31337n;
  const salt = '0x0000000000000000000000000000000000000000000000000000000001000000';
  
  const predictedAddress = await publicClient.readContract({
    address: REGISTRY,
    abi: registryAbi,
    functionName: 'account',
    args: [IMPL, salt, chainId, NFT, tokenId]
  });
  console.log(`2. Predicted TBA address: ${predictedAddress}`);
  const codeBefore = await publicClient.getCode({ address: predictedAddress });
  console.log(`   Code before creation: ${codeBefore?.length || 0} bytes (not deployed)\n`);

  // 3. Create the TBA
  console.log('3. Creating Token Bound Account...');
  const createHash = await walletClient.writeContract({
    address: REGISTRY,
    abi: registryAbi,
    functionName: 'createAccount',
    args: [IMPL, salt, chainId, NFT, tokenId]
  });
  const receipt = await publicClient.waitForTransactionReceipt({ hash: createHash });
  console.log(`   Gas used: ${receipt.gasUsed}\n`);

  // 4. Query TBA 
  const tbaCode = await publicClient.getCode({ address: predictedAddress });
  console.log(`4. TBA deployed! Bytecode: ${(tbaCode?.length || 0) / 2 - 1} bytes`);
  console.log(`   (Minimal proxy: 45 bytes + token data: 128 bytes = 173 bytes)\n`);

  // 5. Query TBA for its bound token
  const tokenInfo = await publicClient.readContract({
    address: predictedAddress,
    abi: accountAbi,
    functionName: 'token'
  });
  console.log('5. TBA is bound to:');
  console.log(`   Chain ID: ${tokenInfo[0]}`);
  console.log(`   NFT Contract: ${tokenInfo[1]}`);
  console.log(`   Token ID: ${tokenInfo[2]}\n`);

  // 6. Check TBA owner
  const tbaOwner = await publicClient.readContract({
    address: predictedAddress,
    abi: accountAbi,
    functionName: 'owner'
  });
  console.log(`6. TBA Owner: ${tbaOwner.slice(0,10)}...`);
  console.log(`   (Same as wallet that owns the NFT!)\n`);

  // 7. Send ETH to TBA
  console.log('7. Sending 1 ETH to TBA...');
  await walletClient.sendTransaction({
    to: predictedAddress,
    value: 1000000000000000000n
  });
  const tbaBalance = await publicClient.getBalance({ address: predictedAddress });
  console.log(`   TBA balance: ${Number(tbaBalance) / 1e18} ETH\n`);

  // 8. Execute from TBA
  const recipient = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
  console.log(`8. Executing: TBA sends 0.5 ETH to ${recipient.slice(0,10)}...`);
  const execHash = await walletClient.writeContract({
    address: predictedAddress,
    abi: accountAbi,
    functionName: 'execute',
    args: [recipient, 500000000000000000n, '0x', 0]
  });
  const execReceipt = await publicClient.waitForTransactionReceipt({ hash: execHash });
  const finalBalance = await publicClient.getBalance({ address: predictedAddress });
  console.log(`   Gas used: ${execReceipt.gasUsed}`);
  console.log(`   TBA balance after: ${Number(finalBalance) / 1e18} ETH\n`);

  console.log('=== Key Takeaways ===');
  console.log('• NFT owner controls the TBA');
  console.log('• TBA can hold ETH/tokens and execute transactions');
  console.log('• If NFT is transferred, new owner controls TBA');
  console.log('• Same address on any chain with same parameters (CREATE2)\n');
}

main().catch(console.error);
