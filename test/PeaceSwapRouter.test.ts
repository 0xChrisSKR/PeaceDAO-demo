import { expect } from "chai";
import { ethers } from "hardhat";

const FEE_BPS = 50n;
const DAO_SHARE_BPS = 8000n;
const FOUNDER_SHARE_BPS = 2000n;
const BPS_DENOMINATOR = 10_000n;

describe("PeaceSwapRouter", function () {
  async function deployFixture() {
    const [deployer, user, daoTreasury, founder] = await ethers.getSigners();

    const TokenFactory = await ethers.getContractFactory("MockERC20");
    const tokenIn = await TokenFactory.deploy("PeaceUSD", "PUSD", 18);
    const tokenOut = await TokenFactory.deploy("PeaceEUR", "PEUR", 18);

    const MockRouter = await ethers.getContractFactory("MockDexRouter");
    const dexRouter = await MockRouter.deploy();

    const FeeCollector = await ethers.getContractFactory("PeaceSwapFeeCollector");
    const feeCollector = await FeeCollector.deploy(
      daoTreasury.address,
      founder.address,
      Number(DAO_SHARE_BPS),
      Number(FOUNDER_SHARE_BPS)
    );

    const PeaceRouter = await ethers.getContractFactory("PeaceSwapRouter");
    const peaceRouter = await PeaceRouter.deploy(
      await dexRouter.getAddress(),
      await feeCollector.getAddress(),
      Number(FEE_BPS)
    );

    const amountIn = ethers.parseUnits("1000", 18);
    await tokenIn.mint(user.address, amountIn);

    const amountOutLiquidity = ethers.parseUnits("5000", 18);
    await tokenOut.mint(await dexRouter.getAddress(), amountOutLiquidity);

    return {
      deployer,
      user,
      daoTreasury,
      founder,
      tokenIn,
      tokenOut,
      dexRouter,
      feeCollector,
      peaceRouter,
      amountIn,
    };
  }

  it("charges fee, distributes to fee collector, and routes remaining tokens", async function () {
    const {
      user,
      daoTreasury,
      founder,
      tokenIn,
      tokenOut,
      peaceRouter,
      feeCollector,
      dexRouter,
      amountIn,
    } = await deployFixture();

    const path = [await tokenIn.getAddress(), await tokenOut.getAddress()];
    const deadline = (await ethers.provider.getBlock("latest")).timestamp + 3600;
    const amountOutMin = ethers.parseUnits("900", 18);

    await tokenIn.connect(user).approve(await peaceRouter.getAddress(), amountIn);

    const fee = (amountIn * FEE_BPS) / BPS_DENOMINATOR;
    const expectedDaoShare = (fee * DAO_SHARE_BPS) / BPS_DENOMINATOR;
    const expectedFounderShare = fee - expectedDaoShare;
    const expectedNet = amountIn - fee;

    await expect(
      peaceRouter
        .connect(user)
        .swapExactTokensForTokensWithFee(amountIn, amountOutMin, path, user.address, deadline)
    )
      .to.emit(peaceRouter, "SwapWithFee")
      .withArgs(user.address, path[0], path[1], amountIn, fee, expectedNet);

    expect(await tokenIn.balanceOf(user.address)).to.equal(0n);
    expect(await tokenOut.balanceOf(user.address)).to.equal(expectedNet);
    expect(await tokenIn.balanceOf(await dexRouter.getAddress())).to.equal(expectedNet);
    expect(await tokenIn.balanceOf(daoTreasury.address)).to.equal(expectedDaoShare);
    expect(await tokenIn.balanceOf(founder.address)).to.equal(expectedFounderShare);
    expect(await tokenIn.balanceOf(await feeCollector.getAddress())).to.equal(0n);
  });
});
