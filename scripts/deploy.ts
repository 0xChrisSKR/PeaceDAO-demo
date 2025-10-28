import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

type DeployConfig = {
  tokenAddress?: string;
  founderWallet?: string;
  peaceFund?: string;
  daoVaultERC20?: string;
  feeCollector?: string;
  router?: string;
};

function loadConfig(): DeployConfig {
  const configPath = path.join(__dirname, "..", "deploy_config.json");
  if (!fs.existsSync(configPath)) {
    return {};
  }
  const raw = fs.readFileSync(configPath, "utf8");
  return JSON.parse(raw);
}

function requireAddress(label: string, value?: string): string {
  if (!value || !ethers.isAddress(value)) {
    throw new Error(`${label} is missing or invalid`);
  }
  return value;
}

async function main() {
  const config = loadConfig();

  const tokenAddress = requireAddress(
    "TOKEN_ADDRESS",
    process.env.TOKEN_ADDRESS || config.tokenAddress
  );
  const founderWallet = requireAddress(
    "FOUNDER_WALLET",
    process.env.FOUNDER_WALLET || config.founderWallet
  );

  const signer = await ethers.provider.getSigner();
  console.log("Deployer:", await signer.getAddress());

  const PeaceGate = await ethers.getContractFactory("PeaceGate");
  const gate = await PeaceGate.deploy(tokenAddress);
  await gate.waitForDeployment();

  const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
  const dao = await PeaceDAO.deploy(tokenAddress, await gate.getAddress());
  await dao.waitForDeployment();

  let peaceFundAddress = process.env.PEACE_FUND_ADDRESS || config.peaceFund;
  if (!peaceFundAddress) {
    const PeaceFund = await ethers.getContractFactory("PeaceFund");
    const peaceFund = await PeaceFund.deploy();
    await peaceFund.waitForDeployment();
    peaceFundAddress = await peaceFund.getAddress();
    const tx = await peaceFund.setDAO(await dao.getAddress());
    await tx.wait();
    console.log("PeaceFund DAO set to:", await dao.getAddress());
  } else {
    requireAddress("PEACE_FUND_ADDRESS", peaceFundAddress);
  }

  let daoVaultAddress = process.env.DAO_VAULT_ERC20 || config.daoVaultERC20;
  const DaoVault = await ethers.getContractFactory("DaoVaultERC20");
  let daoVault;
  if (!daoVaultAddress) {
    daoVault = await DaoVault.deploy(await dao.getAddress(), ethers.ZeroAddress);
    await daoVault.waitForDeployment();
    daoVaultAddress = await daoVault.getAddress();
  } else {
    requireAddress("DAO_VAULT_ERC20", daoVaultAddress);
    daoVault = DaoVault.attach(daoVaultAddress);
  }

  let feeCollectorAddress = process.env.FEE_COLLECTOR_ADDRESS || config.feeCollector;
  const FeeCollector = await ethers.getContractFactory("PeaceSwapFeeCollector");
  let feeCollector;
  if (!feeCollectorAddress) {
    feeCollector = await FeeCollector.deploy(
      requireAddress("daoFundNative", peaceFundAddress),
      requireAddress("daoVaultERC20", daoVaultAddress),
      founderWallet
    );
    await feeCollector.waitForDeployment();
    feeCollectorAddress = await feeCollector.getAddress();
  } else {
    requireAddress("FEE_COLLECTOR_ADDRESS", feeCollectorAddress);
    feeCollector = FeeCollector.attach(feeCollectorAddress);
  }

  if ((await daoVault.feeCollector()) !== feeCollectorAddress) {
    const tx = await daoVault.setFeeCollector(feeCollectorAddress);
    await tx.wait();
    console.log("DaoVaultERC20 fee collector set to:", feeCollectorAddress);
  }

  console.log("PeaceGate:", await gate.getAddress());
  console.log("PeaceDAO :", await dao.getAddress());
  console.log("PeaceFund:", peaceFundAddress);
  console.log("DaoVaultERC20:", daoVaultAddress);
  console.log("FeeCollector:", feeCollectorAddress);
  console.log("Founder Wallet:", founderWallet);
  console.log("Token Address:", tokenAddress);

  const deploymentsPath = path.join(__dirname, "..", "deployments.json");
  const deploymentData = {
    peaceGate: await gate.getAddress(),
    peaceDAO: await dao.getAddress(),
    peaceFund: peaceFundAddress,
    daoVaultERC20: daoVaultAddress,
    feeCollector: feeCollectorAddress,
    router: process.env.UNDERLYING_ROUTER || config.router || "",
    founderWallet,
    tokenAddress,
  };
  fs.writeFileSync(deploymentsPath, JSON.stringify(deploymentData, null, 2));
  console.log("Deployment summary saved to deployments.json");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
