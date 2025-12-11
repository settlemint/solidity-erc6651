import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module for deploying the TokenBoundAccount implementation
 *
 * This deploys the base implementation contract that proxies will delegate to.
 * The implementation is not used directly - accounts are minimal proxies pointing to it.
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/TokenBoundAccount.ts --network <network>
 */
const TokenBoundAccountModule = buildModule("TokenBoundAccount", (m) => {
  // Deploy the implementation contract
  const implementation = m.contract("TokenBoundAccount");

  return { implementation };
});

export default TokenBoundAccountModule;
