import { ethers, network } from "hardhat";

async function main() {
  const peaceFundFactory = await ethers.getContractFactory("PeaceFund");
  const peaceFund = await peaceFundFactory.deploy();
  await peaceFund.waitForDeployment();
  const peaceFundAddress = await peaceFund.getAddress();
  console.log(`{ "network":"${network.name}", "PeaceFund":"${peaceFundAddress}" }`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
