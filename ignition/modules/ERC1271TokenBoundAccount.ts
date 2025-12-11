import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for deploying the ERC1271TokenBoundAccount implementation
 *
 * This deploys the extended implementation with ERC-1271 signature validation.
 * Use this implementation when you need accounts that can validate signatures.
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/ERC1271TokenBoundAccount.ts --network <network>
 */
const ERC1271TokenBoundAccountModule = buildModule("ERC1271TokenBoundAccount", (m) => {
  // Deploy the implementation contract
  const implementation = m.contract("ERC1271TokenBoundAccount");

  return { implementation };
});

export default ERC1271TokenBoundAccountModule;
