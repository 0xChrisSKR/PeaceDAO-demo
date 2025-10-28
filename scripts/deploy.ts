import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  const configPath = path.resolve(__dirname, "..", "deploy_config.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const PeaceGate = await ethers.getContractFactory("PeaceGate");
  const gate = await PeaceGate.deploy(config.token);
  await gate.waitForDeployment();

  const PeaceFund = await ethers.getContractFactory("PeaceFund");
  const fund = await PeaceFund.deploy();
  await fund.waitForDeployment();

  const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
  const dao = await PeaceDAO.deploy(config.token, await gate.getAddress(), await fund.getAddress());
  await dao.waitForDeployment();

  await fund.setDAO(await dao.getAddress());

  const FeeCollector = await ethers.getContractFactory("PeaceSwapFeeCollector");
  const feeCollector = await FeeCollector.deploy(
    config.daoTreasury,
    config.founderWallet,
    config.swapParams.daoShareBps,
    config.swapParams.founderShareBps
  );
  await feeCollector.waitForDeployment();

  const PeaceSwapRouter = await ethers.getContractFactory("PeaceSwapRouter");
  const peaceSwapRouter = await PeaceSwapRouter.deploy(
    config.swapParams.underlyingRouter,
    await feeCollector.getAddress(),
    config.swapParams.feeBps
  );
  await peaceSwapRouter.waitForDeployment();

  const deployments = {
    PeaceGate: await gate.getAddress(),
    PeaceFund: await fund.getAddress(),
    PeaceDAO: await dao.getAddress(),
    PeaceSwapFeeCollector: await feeCollector.getAddress(),
    PeaceSwapRouter: await peaceSwapRouter.getAddress(),
  };

  const deploymentsPath = path.resolve(__dirname, "..", "deployments.json");
  fs.writeFileSync(deploymentsPath, JSON.stringify(deployments, null, 2));

  console.log("PeaceGate:", deployments.PeaceGate);
  console.log("PeaceFund:", deployments.PeaceFund);
  console.log("PeaceDAO :", deployments.PeaceDAO);
  console.log("FeeCollector:", deployments.PeaceSwapFeeCollector);
  console.log("PeaceSwapRouter:", deployments.PeaceSwapRouter);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
