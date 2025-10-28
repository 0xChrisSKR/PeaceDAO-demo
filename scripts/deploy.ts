import { ethers, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import * as dotenv from "dotenv";

dotenv.config();

type DeployConfig = {
  network?: string;
  tokenAddress: string;
  founderWallet: string;
  daoParams: {
    voteThreshold: string;
    proposeThreshold: string;
    votingPeriodSeconds: number;
    extraStakeLockSeconds: number;
    treasuryUsdMinForProposal: number;
  };
  fundParams: { opsKeepBps: number };
  swapParams: {
    feeBps: number;
    daoShareBps: number;
    founderShareBps: number;
    underlyingRouter: string;
  };
  verifyParams: { rewardPpm: number };
  managerParams: {
    minStake: string;
    maxManagers: number;
    termSeconds: number;
    managerRewardPpm: number;
  };
};

const CONFIG_PATH = path.join(__dirname, "..", "deploy_config.json");

function loadConfig(): DeployConfig {
  const raw = fs.readFileSync(CONFIG_PATH, "utf8");
  return JSON.parse(raw);
}

function requireAddress(label: string, value: string, allowPlaceholder = false): string {
  if (!value || value.trim() === "") {
    throw new Error(`Missing ${label}`);
  }
  if (allowPlaceholder && value.startsWith("0xROUTER")) {
    throw new Error(`Replace placeholder value for ${label}`);
  }
  if (!ethers.isAddress(value)) {
    throw new Error(`Invalid ${label}: ${value}`);
  }
  return value;
}

function requireBps(label: string, fallback: number | undefined, envValue: string | undefined): number {
  const input = envValue ?? (fallback !== undefined ? fallback.toString() : undefined);
  if (!input) {
    throw new Error(`Missing ${label}`);
  }
  const parsed = Number(input);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`Invalid ${label}: ${input}`);
  }
  return parsed;
}

async function main() {
  const config = loadConfig();
  if (config.network && config.network !== network.name) {
    console.warn(`⚠️  Config network is ${config.network}, current Hardhat network is ${network.name}`);
  }

  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error("No deployer account available");
  }

  const tokenAddress = requireAddress(
    "TOKEN_ADDRESS",
    process.env.TOKEN_ADDRESS || config.tokenAddress
  );
  const founderWallet = requireAddress(
    "FOUNDER_WALLET",
    process.env.FOUNDER_WALLET || config.founderWallet
  );

  const underlyingRouter = requireAddress(
    "UNDERLYING_ROUTER",
    process.env.UNDERLYING_ROUTER || config.swapParams.underlyingRouter,
    true
  );

  const swapFeeBps = requireBps("SWAP_FEE_BPS", config.swapParams.feeBps, process.env.SWAP_FEE_BPS);
  const daoShareBps = requireBps("DAO_SHARE_BPS", config.swapParams.daoShareBps, process.env.DAO_SHARE_BPS);
  const founderShareBps = requireBps(
    "FOUNDER_SHARE_BPS",
    config.swapParams.founderShareBps,
    process.env.FOUNDER_SHARE_BPS
  );
  if (daoShareBps + founderShareBps !== 10_000) {
    throw new Error("DAO share + founder share must equal 10000 bps (100%)");
  }

  console.log("Deploying with account:", await deployer.getAddress());
  console.log("Token:", tokenAddress);
  console.log("Founder wallet:", founderWallet);

  const tokenContract = new ethers.Contract(
    tokenAddress,
    ["function decimals() view returns (uint8)"],
    deployer
  );
  const decimals: number = await tokenContract.decimals();

  const gateFactory = await ethers.getContractFactory("PeaceGate");
  const gate = await gateFactory.deploy(tokenAddress);
  await gate.waitForDeployment();

  const voteThreshold = ethers.parseUnits(config.daoParams.voteThreshold, decimals);
  const proposeThreshold = ethers.parseUnits(config.daoParams.proposeThreshold, decimals);
  const speakThreshold = ethers.parseUnits("100", decimals);
  await (await gate.setThresholds(speakThreshold, voteThreshold, proposeThreshold)).wait();

  const fundFactory = await ethers.getContractFactory("PeaceFund");
  const fund = await fundFactory.deploy();
  await fund.waitForDeployment();

  const daoFactory = await ethers.getContractFactory("PeaceDAO");
  const dao = await daoFactory.deploy(tokenAddress, await gate.getAddress(), await fund.getAddress());
  await dao.waitForDeployment();

  await (await fund.setDAO(await dao.getAddress())).wait();

  const feeCollectorFactory = await ethers.getContractFactory("PeaceSwapFeeCollector");
  const feeCollector = await feeCollectorFactory.deploy(
    await fund.getAddress(),
    founderWallet,
    daoShareBps,
    founderShareBps
  );
  await feeCollector.waitForDeployment();

  const routerFactory = await ethers.getContractFactory("PeaceSwapRouter");
  const router = await routerFactory.deploy(await feeCollector.getAddress(), underlyingRouter, swapFeeBps);
  await router.waitForDeployment();

  console.log("PeaceGate deployed:", await gate.getAddress());
  console.log("PeaceFund deployed:", await fund.getAddress());
  console.log("PeaceDAO deployed:", await dao.getAddress());
  console.log("PeaceSwapFeeCollector deployed:", await feeCollector.getAddress());
  console.log("PeaceSwapRouter deployed:", await router.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
