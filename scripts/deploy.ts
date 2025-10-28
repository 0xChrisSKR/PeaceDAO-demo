import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import "dotenv/config";

type DeployConfig = {
  network: string;
  tokenAddress: string;
  founderWallet: string;
  daoParams: {
    voteThreshold: string;
    proposeThreshold: string;
    votingPeriodSeconds: number;
    extraStakeLockSeconds: number;
    treasuryUsdMinForProposal: number;
  };
  fundParams: {
    opsKeepBps: number;
  };
  swapParams: {
    feeBps: number;
    daoShareBps: number;
    founderShareBps: number;
    underlyingRouter: string;
  };
  verifyParams: {
    rewardPpm: number;
  };
  managerParams: {
    minStake: string;
    maxManagers: number;
    termSeconds: number;
    managerRewardPpm: number;
  };
};

function readConfig(): DeployConfig {
  const configPath = path.resolve(__dirname, "..", "deploy_config.json");
  const raw = fs.readFileSync(configPath, "utf8");
  return JSON.parse(raw) as DeployConfig;
}

function pickEnv(key: string, fallback: string) {
  const value = process.env[key];
  return value && value.length > 0 ? value : fallback;
}

async function main() {
  const cfg = readConfig();
  const [deployer] = await ethers.getSigners();

  const tokenAddress = pickEnv("TOKEN_ADDRESS", cfg.tokenAddress);
  const founderWallet = pickEnv("FOUNDER_WALLET", cfg.founderWallet);
  const underlyingRouter = pickEnv("UNDERLYING_ROUTER", cfg.swapParams.underlyingRouter);
  const swapFeeBps = Number(pickEnv("SWAP_FEE_BPS", String(cfg.swapParams.feeBps)));
  const daoShareBps = Number(pickEnv("DAO_SHARE_BPS", String(cfg.swapParams.daoShareBps)));
  const founderShareBps = Number(pickEnv("FOUNDER_SHARE_BPS", String(cfg.swapParams.founderShareBps)));

  console.log("Network:", cfg.network);
  console.log("Deployer:", deployer.address);
  console.log("Token  :", tokenAddress);

  const PeaceFund = await ethers.getContractFactory("PeaceFund");
  const fund = await PeaceFund.deploy();
  await fund.waitForDeployment();
  console.log("PeaceFund deployed at", await fund.getAddress());

  const PeaceGate = await ethers.getContractFactory("PeaceGate");
  const gate = await PeaceGate.deploy(tokenAddress);
  await gate.waitForDeployment();
  console.log("PeaceGate deployed at", await gate.getAddress());

  const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
  const dao = await PeaceDAO.deploy(tokenAddress, await gate.getAddress(), await fund.getAddress());
  await dao.waitForDeployment();
  console.log("PeaceDAO deployed at", await dao.getAddress());

  const PeaceSwapFeeCollector = await ethers.getContractFactory("PeaceSwapFeeCollector");
  const feeCollector = await PeaceSwapFeeCollector.deploy(
    await fund.getAddress(),
    founderWallet,
    daoShareBps,
    founderShareBps
  );
  await feeCollector.waitForDeployment();
  console.log("PeaceSwapFeeCollector deployed at", await feeCollector.getAddress());

  const PeaceSwapRouter = await ethers.getContractFactory("PeaceSwapRouter");
  const router = await PeaceSwapRouter.deploy(underlyingRouter, await feeCollector.getAddress(), swapFeeBps);
  await router.waitForDeployment();
  console.log("PeaceSwapRouter deployed at", await router.getAddress());

  const tx = await fund.setDAO(await dao.getAddress());
  await tx.wait();
  console.log("PeaceFund DAO set to", await dao.getAddress());

  const updateRouterTx = await feeCollector.setRouter(await router.getAddress());
  await updateRouterTx.wait();
  console.log("PeaceSwapFeeCollector router set to", await router.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
