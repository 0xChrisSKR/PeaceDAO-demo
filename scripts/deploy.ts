import { ethers } from "hardhat";

async function main() {
  const token = "0xYourWorldPeaceTokenOnTestnet"; // 先填暫時值
  const PeaceGate = await ethers.getContractFactory("PeaceGate");
  const gate = await PeaceGate.deploy(token);
  await gate.waitForDeployment();

  const PeaceFund = await ethers.getContractFactory("PeaceFund");
  const fund = await PeaceFund.deploy(
    await ethers.getSigner().then((s) => s.address),
    1_000,
    50,
    3
  );
  await fund.waitForDeployment();

  const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
  const dao = await PeaceDAO.deploy(token, await gate.getAddress(), await fund.getAddress());
  await dao.waitForDeployment();

  await fund.setDAO(await dao.getAddress());

  console.log("PeaceGate:", await gate.getAddress());
  console.log("PeaceFund:", await fund.getAddress());
  console.log("PeaceDAO :", await dao.getAddress());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
