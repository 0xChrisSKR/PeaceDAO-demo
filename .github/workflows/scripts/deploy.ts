import { ethers } from "hardhat";

async function main() {
  const token = "0xYourWorldPeaceTokenOnTestnet";
  const PeaceGate = await ethers.getContractFactory("PeaceGate");
  const gate = await PeaceGate.deploy(token);
  await gate.waitForDeployment();

  const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
  const dao = await PeaceDAO.deploy(token, await gate.getAddress());
  await dao.waitForDeployment();

  console.log("PeaceGate:", await gate.getAddress());
  console.log("PeaceDAO :", await dao.getAddress());
}

main().catch((e) => { console.error(e); process.exit(1); });
