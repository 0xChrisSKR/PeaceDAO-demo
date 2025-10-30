import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";

describe("PeaceDAO governance with Treasury", function () {
  async function deployFixture() {
    const [deployer, proposer, voter, validator, recipient] = await ethers.getSigners();

    const MockToken = await ethers.getContractFactory("MockERC20");
    const initialSupply = ethers.parseEther("10000000");
    const token = await MockToken.deploy("Mock Token", "MOCK", initialSupply);
    await token.waitForDeployment();

    await token.transfer(proposer.address, ethers.parseEther("2000000"));
    await token.transfer(voter.address, ethers.parseEther("1000000"));
    await token.transfer(validator.address, ethers.parseEther("100000"));

    const PeaceDAO = await ethers.getContractFactory("PeaceDAO");
    const dao = await PeaceDAO.deploy(await token.getAddress());
    await dao.waitForDeployment();

    const Treasury = await ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy(await dao.getAddress());
    await treasury.waitForDeployment();

    await dao.setTreasury(await treasury.getAddress());

    const quorum = ethers.parseEther("200000");
    const passRatioBps = 6000;
    const minValidatorLikes = 1;
    await dao.setGovernanceParams(quorum, passRatioBps, minValidatorLikes);

    await token.connect(voter).approve(await dao.getAddress(), ethers.MaxUint256);

    return {
      token,
      dao,
      treasury,
      deployer,
      proposer,
      voter,
      validator,
      recipient,
    };
  }

  it("reverts Treasury payout when validators fail despite passing vote", async function () {
    const { dao, treasury, token, proposer, voter, recipient } = await loadFixture(deployFixture);

    const payoutAmount = ethers.parseEther("1");
    await dao.connect(proposer).proposePayout(ethers.ZeroAddress, recipient.address, payoutAmount);
    const proposalId = await dao.proposalCount();

    const stakeAmount = ethers.parseEther("200000");
    await dao.connect(voter).vote(proposalId, true, stakeAmount);

    await time.increase(24 * 60 * 60 + 1);
    await dao.finalize(proposalId);

    expect(await dao.isExecutable(proposalId)).to.equal(false);
    await expect(treasury.executePayout(proposalId)).to.be.revertedWith("Not executable");

    const daoBalance = await token.balanceOf(await dao.getAddress());
    expect(daoBalance).to.equal(stakeAmount);
  });

  it("executes Treasury payout when vote and validators pass", async function () {
    const { dao, treasury, proposer, voter, validator, recipient } = await loadFixture(deployFixture);

    const payoutAmount = ethers.parseEther("1");
    const proposalId = await createProposal(dao, proposer, recipient, payoutAmount);

    const stakeAmount = ethers.parseEther("300000");
    await dao.connect(voter).vote(proposalId, true, stakeAmount);
    await dao.connect(validator).validate(proposalId, true);

    await time.increase(24 * 60 * 60 + 1);
    await dao.finalize(proposalId);

    await proposer.sendTransaction({
      to: await treasury.getAddress(),
      value: payoutAmount,
    });

    const before = await ethers.provider.getBalance(recipient.address);
    const execTx = await treasury.executePayout(proposalId);
    await execTx.wait();
    const after = await ethers.provider.getBalance(recipient.address);

    expect(after - before).to.equal(payoutAmount);
    expect(await dao.isExecutable(proposalId)).to.equal(false);
    await expect(treasury.executePayout(proposalId)).to.be.revertedWith("Not executable");
  });

  it("allows voters to reclaim their stake after voting period", async function () {
    const { dao, token, proposer, voter, recipient } = await loadFixture(deployFixture);

    const proposalId = await createProposal(dao, proposer, recipient, ethers.parseEther("1"));
    const stakeAmount = ethers.parseEther("250000");
    await dao.connect(voter).vote(proposalId, true, stakeAmount);

    await time.increase(24 * 60 * 60 + 1);

    const before = await token.balanceOf(voter.address);
    const claimTx = await dao.connect(voter).claimStake(proposalId);
    await expect(claimTx).to.emit(dao, "StakeClaimed").withArgs(proposalId, voter.address, stakeAmount);
    const after = await token.balanceOf(voter.address);

    expect(after - before).to.equal(stakeAmount);
    expect(await dao.stakeOf(proposalId, voter.address)).to.equal(0n);
  });

  async function createProposal(
    dao: any,
    proposer: any,
    recipient: any,
    amount: bigint
  ): Promise<bigint> {
    await dao.connect(proposer).proposePayout(ethers.ZeroAddress, recipient.address, amount);
    return dao.proposalCount();
  }
});
