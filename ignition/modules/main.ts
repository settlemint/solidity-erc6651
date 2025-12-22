import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Main deployment module for ERC-6551 Token Bound Accounts
 *
 * Deploys:
 * - ERC6551Registry: Central registry for creating accounts
 * - ERC6551BatchRegistry: Gas-optimized batch account creation
 * - TokenBoundAccount: Base implementation
 * - ERC1271TokenBoundAccount: Implementation with signature validation
 * - ExampleNFT: Test NFT for demonstration
 * - ExampleUsage: Integration example contract
 */
const ERC6551Module = buildModule("ERC6551Module", (m) => {
  // Deploy the registry
  const registry = m.contract("ERC6551Registry");

  // Deploy batch registry wrapper
  const batchRegistry = m.contract("ERC6551BatchRegistry", [registry]);

  // Deploy implementations
  const tokenBoundAccount = m.contract("TokenBoundAccount");
  const erc1271Account = m.contract("ERC1271TokenBoundAccount");

  // Deploy example NFT
  const exampleNFT = m.contract("ExampleNFT", [
    "Example Token Bound NFT",
    "TBNFT",
    "https://example.com/metadata/"
  ]);

  // Deploy example usage contract
  const exampleUsage = m.contract("ExampleUsage", [registry, tokenBoundAccount]);

  return {
    registry,
    batchRegistry,
    tokenBoundAccount,
    erc1271Account,
    exampleNFT,
    exampleUsage,
  };
});

export default ERC6551Module;
