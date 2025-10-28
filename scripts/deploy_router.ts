import { ethers, network } from "hardhat";
import "dotenv/config";

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value || value.length === 0) {
    throw new Error(`${key} environment variable is required`);
  }
  return value;
}

function parseBps(key: string, fallback: number): number {
  const raw = process.env[key];
  if (!raw || raw.length === 0) {
    return fallback;
  }
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    throw new Error(`${key} must be a number`);
  }
  return value;
}

async function main() {
  const peaceFundAddress = requireEnv("PEACE_FUND_ADDRESS");
  const founderWallet = requireEnv("FOUNDER_WALLET");
  const underlyingRouter = requireEnv("UNDERLYING_ROUTER");
  const swapFeeBps = parseBps("SWAP_FEE_BPS", 50);
  const daoShareBps = parseBps("DAO_SHARE_BPS", 8000);
  const founderShareBps = parseBps("FOUNDER_SHARE_BPS", 2000);

  if (daoShareBps + founderShareBps !== 10_000) {
    throw new Error("DAO_SHARE_BPS plus FOUNDER_SHARE_BPS must equal 10000");
  }

  const feeCollectorFactory = await ethers.getContractFactory("PeaceSwapFeeCollector");
  const feeCollector = await feeCollectorFactory.deploy(
    peaceFundAddress,
    founderWallet,
    daoShareBps,
    founderShareBps
  );
  await feeCollector.waitForDeployment();

  const routerFactory = await ethers.getContractFactory("PeaceSwapRouter");
  const router = await routerFactory.deploy(underlyingRouter, await feeCollector.getAddress(), swapFeeBps);
  await router.waitForDeployment();

  const routerAddress = await router.getAddress();
  console.log(`{ "network":"${network.name}", "PeaceSwapRouter":"${routerAddress}" }`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
