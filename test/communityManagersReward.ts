import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("PeaceDAO community manager rewards", function () {
  async function deployFixture() {
    const [owner, proposer, voter, destination, manager1, manager2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockToken");
    const token = await Token.deploy("World Peace", "PEACE", 18);
    await token.waitForDeployment();

    const Gate = await ethers.getContractFactory("PeaceGate");
    const gate = await Gate.deploy(await token.getAddress());
    await gate.waitForDeployment();

    const Fund = await ethers.getContractFactory("PeaceFund");
    const fund = await Fund.deploy();
    await fund.waitForDeployment();

    const DAO = await ethers.getContractFactory("PeaceDAO");
    const dao = await DAO.deploy(await token.getAddress(), await gate.getAddress(), await fund.getAddress());
    await dao.waitForDeployment();

    await fund.setDAO(await dao.getAddress());
    await gate.setThresholds(0, 0, 0);

    const stakeAmount = await dao.stakeAmount();
    await dao.setParams(stakeAmount, 0, 5, 0);

    return { owner, proposer, voter, destination, manager1, manager2, token, gate, fund, dao, stakeAmount };
  }

  it("pays rewards to community managers on successful execution", async function () {
    const { proposer, voter, destination, manager1, manager2, token, fund, dao, stakeAmount } = await loadFixture(deployFixture);

    await token.mint(proposer.address, stakeAmount);
    await token.connect(proposer).approve(await dao.getAddress(), stakeAmount);

    const voterStake = ethers.parseUnits("10", 18);
    await token.mint(voter.address, voterStake);

    const rewardPerManager = ethers.parseEther("1");
    await dao.setCommunityManagers([manager1.address, manager2.address]);
    await dao.setCommunityReward(rewardPerManager);

    const nativeAmount = ethers.parseEther("3");
    const depositAmount = nativeAmount + rewardPerManager * 2n;
    await fund.donate({ value: depositAmount });

    const tx = await dao
      .connect(proposer)
      .propose("Reward community managers", "reward", destination.address, nativeAmount);
    await tx.wait();
    const proposalId = await dao.proposalCount();

    await dao.connect(voter).castVote(proposalId, true);

    await ethers.provider.send("hardhat_mine", ["0x6"]);

    const destinationBalanceBefore = await ethers.provider.getBalance(destination.address);
    const manager1BalanceBefore = await ethers.provider.getBalance(manager1.address);
    const manager2BalanceBefore = await ethers.provider.getBalance(manager2.address);

    await expect(dao.execute(proposalId))
      .to.emit(dao, "CommunityManagerRewardPaid")
      .withArgs(proposalId, manager1.address, rewardPerManager)
      .and.to.emit(dao, "CommunityManagerRewardPaid")
      .withArgs(proposalId, manager2.address, rewardPerManager);

    const destinationBalanceAfter = await ethers.provider.getBalance(destination.address);
    const manager1BalanceAfter = await ethers.provider.getBalance(manager1.address);
    const manager2BalanceAfter = await ethers.provider.getBalance(manager2.address);

    expect(destinationBalanceAfter - destinationBalanceBefore).to.equal(nativeAmount);
    expect(manager1BalanceAfter - manager1BalanceBefore).to.equal(rewardPerManager);
    expect(manager2BalanceAfter - manager2BalanceBefore).to.equal(rewardPerManager);

    expect(await token.balanceOf(proposer.address)).to.equal(stakeAmount);
  });

  it("resets and validates community manager configuration", async function () {
    const { dao, manager1, manager2 } = await loadFixture(deployFixture);

    await expect(dao.setCommunityManagers([manager1.address, ethers.ZeroAddress])).to.be.revertedWith("manager=0");

    await dao.setCommunityManagers([manager1.address]);
    expect(await dao.isCommunityManager(manager1.address)).to.equal(true);

    await dao.setCommunityManagers([manager2.address]);
    expect(await dao.isCommunityManager(manager1.address)).to.equal(false);
    expect(await dao.isCommunityManager(manager2.address)).to.equal(true);

    const managers = await dao.getCommunityManagers();
    expect(managers).to.deep.equal([manager2.address]);

    await expect(dao.setCommunityManagers([manager2.address, manager2.address])).to.be.revertedWith(
      "duplicate manager"
    );
  });
});
