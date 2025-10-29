import { ethers, network } from "hardhat";
import "dotenv/config";

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value || value.length === 0) {
    throw new Error(`${key} environment variable is required`);
  }
  return value;
}

async function main() {
  const tokenAddress = requireEnv("TOKEN_ADDRESS");
  const gateAddress = requireEnv("PEACE_GATE_ADDRESS");
  const fundAddress = requireEnv("PEACE_FUND_ADDRESS");

  const daoFactory = await ethers.getContractFactory("PeaceDAO");
  const dao = await daoFactory.deploy(tokenAddress, gateAddress, fundAddress);
  await dao.waitForDeployment();

  const daoAddress = await dao.getAddress();
  console.log(`{ "network":"${network.name}", "PeaceDAO":"${daoAddress}" }`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
