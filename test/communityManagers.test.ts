import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Community Manager rewards", function () {
  async function deployFixture() {
    const [deployer, founder, proposer, voter, manager1, manager2, manager3, manager4, verifier, beneficiary] =
      await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockERC20");
    const token = await Token.deploy("World Peace", "和平", 18);
    await token.waitForDeployment();

    const Gate = await ethers.getContractFactory("MockGate");
    const gate = await Gate.deploy();
    await gate.waitForDeployment();

    const Fund = await ethers.getContractFactory("PeaceFund");
    const fund = await Fund.deploy(founder.address, 1_000, 50, 3);
    await fund.waitForDeployment();

    const Dao = await ethers.getContractFactory("PeaceDAO");
    const dao = await Dao.deploy(await token.getAddress(), await gate.getAddress(), await fund.getAddress());
    await dao.waitForDeployment();

    const Verify = await ethers.getContractFactory("PeaceVerify");
    const verify = await Verify.deploy(await dao.getAddress());
    await verify.waitForDeployment();

    await fund.connect(deployer).setDAO(await dao.getAddress());
    await dao.connect(deployer).setVerifierContract(await verify.getAddress());

    return {
      deployer,
      founder,
      proposer,
      voter,
      manager1,
      manager2,
      manager3,
      manager4,
      verifier,
      beneficiary,
      token,
      gate,
      fund,
      dao,
      verify,
    };
  }

  async function mintAndApprove(
    token: any,
    holder: any,
    spender: string,
    amount: bigint
  ) {
    await token.mint(holder.address, amount);
    await token.connect(holder).approve(spender, amount);
  }

  it("appoints managers with required stake and syncs fund", async function () {
    const { dao, fund, token, manager1, deployer } = await deployFixture();
    const managerStake = await dao.managerStakeRequired();
    const termEnd = (await time.latest()) + 7 * 24 * 60 * 60;

    await mintAndApprove(token, manager1, await dao.getAddress(), managerStake);

    await expect(dao.connect(deployer).appointManagers([manager1.address], termEnd))
      .to.emit(dao, "ManagersAppointed")
      .withArgs([manager1.address], termEnd);

    expect(await dao.isManager(manager1.address)).to.equal(true);
    expect(await dao.getActiveManagers()).to.deep.equal([manager1.address]);
    expect(await fund.getActiveManagers()).to.deep.equal([manager1.address]);
    expect(await token.balanceOf(manager1.address)).to.equal(0n);
  });

  it("rejects appointments beyond MAX_MANAGERS", async function () {
    const { dao, token, manager1, manager2, manager3, manager4, deployer } = await deployFixture();
    const managerStake = await dao.managerStakeRequired();
    const daoAddress = await dao.getAddress();
    const termEnd = (await time.latest()) + 30 * 24 * 60 * 60;

    for (const manager of [manager1, manager2, manager3]) {
      await mintAndApprove(token, manager, daoAddress, managerStake);
    }

    await dao.connect(deployer).appointManagers(
      [manager1.address, manager2.address, manager3.address],
      termEnd
    );

    await mintAndApprove(token, manager4, daoAddress, managerStake);
    await expect(dao.connect(deployer).appointManagers([manager4.address], termEnd))
      .to.be.revertedWith("max exceeded");
  });

  it("distributes donation rewards to verifier, managers, and founder", async function () {
    const {
      dao,
      fund,
      token,
      gate,
      verify,
      deployer,
      proposer,
      voter,
      manager1,
      manager2,
      verifier,
      beneficiary,
      founder,
    } = await deployFixture();

    const daoAddress = await dao.getAddress();
    const managerStake = await dao.managerStakeRequired();
    const stakeAmount = await dao.stakeAmount();
    const termEnd = (await time.latest()) + 14 * 24 * 60 * 60;

    for (const manager of [manager1, manager2]) {
      await mintAndApprove(token, manager, daoAddress, managerStake);
    }
    await dao.connect(deployer).appointManagers([manager1.address, manager2.address], termEnd);

    const base = 10n ** BigInt(await token.decimals());
    const voterBalance = 5_000_000n * base;

    await mintAndApprove(token, proposer, daoAddress, stakeAmount);
    await token.mint(voter.address, voterBalance);

    await gate.setProposer(proposer.address, true);
    await gate.setVoter(proposer.address, true);
    await gate.setVoter(voter.address, true);

    await dao.connect(deployer).setParams(stakeAmount, 0, 1, 1n);

    const donationAmount = ethers.parseEther("100");
    await deployer.sendTransaction({ to: await fund.getAddress(), value: donationAmount });

    const proposalTx = await dao
      .connect(proposer)
      .propose("Relief donation", "Support community center", beneficiary.address, donationAmount);
    await proposalTx.wait();

    const proposalId = await dao.proposalCount();

    await time.advanceBlock();

    await dao.connect(voter).castVote(proposalId, true);

    await time.advanceBlock();
    await time.advanceBlock();

    await verify.connect(deployer).submitVerification(proposalId, verifier.address);

    const beneficiaryBefore = await ethers.provider.getBalance(beneficiary.address);
    const verifierBefore = await ethers.provider.getBalance(verifier.address);
    const founderBefore = await ethers.provider.getBalance(founder.address);
    const manager1Before = await ethers.provider.getBalance(manager1.address);
    const manager2Before = await ethers.provider.getBalance(manager2.address);

    await dao.connect(deployer).execute(proposalId);

    const opsKeepBps = await fund.opsKeepBps();
    const rewardPpm = await fund.rewardPpm();

    const opsAmount = (donationAmount * opsKeepBps) / 10_000n;
    const beneficiaryAmount = donationAmount - opsAmount;
    const verifierReward = (donationAmount * rewardPpm) / 1_000_000n;
    const managersReward = (donationAmount * rewardPpm) / 1_000_000n;
    const opsRemainder = opsAmount - verifierReward - managersReward;

    expect((await ethers.provider.getBalance(beneficiary.address)) - beneficiaryBefore).to.equal(beneficiaryAmount);
    expect((await ethers.provider.getBalance(verifier.address)) - verifierBefore).to.equal(verifierReward);
    expect((await ethers.provider.getBalance(founder.address)) - founderBefore).to.equal(opsRemainder);

    const activeManagers = await fund.getActiveManagers();
    expect(activeManagers).to.deep.equal([manager1.address, manager2.address]);

    const share = managersReward / BigInt(activeManagers.length);
    let remainder = managersReward % BigInt(activeManagers.length);
    const managerBalancesAfter = [
      (await ethers.provider.getBalance(manager1.address)) - manager1Before,
      (await ethers.provider.getBalance(manager2.address)) - manager2Before,
    ];

    for (let i = 0; i < activeManagers.length; i++) {
      const expected = share + (remainder > 0n ? 1n : 0n);
      if (remainder > 0n) remainder -= 1n;
      expect(managerBalancesAfter[i]).to.equal(expected);
    }
  });

  it("unlocks stake after removal when term ends", async function () {
    const { dao, token, manager1, deployer } = await deployFixture();
    const managerStake = await dao.managerStakeRequired();
    const daoAddress = await dao.getAddress();
    const termEnd = (await time.latest()) + 5 * 24 * 60 * 60;

    await mintAndApprove(token, manager1, daoAddress, managerStake);
    await dao.connect(deployer).appointManagers([manager1.address], termEnd);

    await dao.connect(deployer).removeManagers([manager1.address]);

    await expect(dao.connect(manager1).claimManagerStake()).to.be.revertedWith("term");

    await time.increaseTo(termEnd + 1);

    const balanceBefore = await token.balanceOf(manager1.address);
    await dao.connect(manager1).claimManagerStake();
    const balanceAfter = await token.balanceOf(manager1.address);

    expect(balanceAfter - balanceBefore).to.equal(managerStake);
    expect(await dao.isManager(manager1.address)).to.equal(false);
  });
});
