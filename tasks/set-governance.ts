import { task } from "hardhat/config";
import type { HardhatRuntimeEnvironment } from "hardhat/types";
import "dotenv/config";

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value || value.length === 0) {
    throw new Error(`${key} environment variable is required`);
  }
  return value;
}

async function updateGovernanceParams(hre: HardhatRuntimeEnvironment) {
  const daoAddress = requireEnv("PEACEDAO_ADDRESS");
  const contract = await hre.ethers.getContractAt("PeaceDAO", daoAddress);

  const proposeThreshold = hre.ethers.parseUnits("1000000", 18);
  const voteThreshold = hre.ethers.parseUnits("200000", 18);
  const speakThreshold = hre.ethers.parseUnits("15000", 18);

  const thresholdsTx = await contract.setThresholds(
    proposeThreshold,
    voteThreshold,
    speakThreshold
  );
  await thresholdsTx.wait();
  console.log("Updated thresholds for governance roles");

  const governParamsTx = await contract.setGovernParams(1000, 6000, 5500);
  await governParamsTx.wait();
  console.log("Updated governance parameters");
}

task("set-govern", "Sets PeaceDAO governance thresholds and parameters")
  .setAction(async (_, hre) => {
    await updateGovernanceParams(hre);
  });
