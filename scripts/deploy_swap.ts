import { ethers } from "hardhat";

async function main() {
  const baseRouter = "0xYourPreferredDexRouter"; // Pancake / Uniswap router
  const daoTreasury = "0xYourPeaceDaoTreasury";
  const founderWallet = "0xYourFounderWallet";

  if (baseRouter === ethers.ZeroAddress) {
    throw new Error("baseRouter not configured");
  }
  if (daoTreasury === ethers.ZeroAddress || founderWallet === ethers.ZeroAddress) {
    throw new Error("recipients not configured");
  }

  const FeeCollector = await ethers.getContractFactory("PeaceSwapFeeCollector");
  const feeCollector = await FeeCollector.deploy(daoTreasury, founderWallet);
  await feeCollector.waitForDeployment();

  const PeaceSwapRouter = await ethers.getContractFactory("PeaceSwapRouter");
  const router = await PeaceSwapRouter.deploy(baseRouter, await feeCollector.getAddress());
  await router.waitForDeployment();

  console.log("PeaceSwapFeeCollector:", await feeCollector.getAddress());
  console.log("PeaceSwapRouter      :", await router.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
