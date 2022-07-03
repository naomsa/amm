import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { AMM, MockERC20 } from "../typechain";

describe("AMM v1", () => {
  let [owner, addr1]: SignerWithAddress[] = [];
  let amm: AMM;
  let token0: MockERC20;
  let token1: MockERC20;

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();

    [token0, token1] = [
      await (await ethers.getContractFactory("MockERC20")).deploy(),
      await (await ethers.getContractFactory("MockERC20")).deploy(),
    ];

    amm = await (
      await ethers.getContractFactory("AMM")
    ).deploy(token0.address, token1.address);

    for (const token of [token0, token1]) {
      for (const addr of [owner, addr1]) {
        await token
          .connect(addr)
          .approve(amm.address, ethers.constants.MaxUint256);
      }
    }
  });

  it("Should correctly initialize", async () => {
    expect(await amm.token0()).to.equal(token0.address);
    expect(await amm.token1()).to.equal(token1.address);
    expect(await amm.reserve0()).to.equal(0);
    expect(await amm.reserve1()).to.equal(0);
    expect(await token0.balanceOf(owner.address)).to.equal(100);
    expect(await token1.balanceOf(owner.address)).to.equal(100);
  });

  describe("addLiquidity()", () => {
    it("Should correctly provide liquidity", async () => {
      const amount0 = 1;
      const amount1 = 4;

      await amm.addLiquidity(amount0, amount1);

      expect(await token0.balanceOf(owner.address)).to.equal(100 - amount0);
      expect(await token1.balanceOf(owner.address)).to.equal(100 - amount1);
      expect(await amm.reserve0()).to.equal(amount0);
      expect(await amm.reserve1()).to.equal(amount1);
      expect(await amm.balanceOf(owner.address)).to.equal(
        Math.sqrt(amount0 * amount1),
      );
    });

    it("Should revert when not adding proportional liquidity", async () => {
      await amm.addLiquidity(1, 1);
      await expect(amm.addLiquidity(2, 1)).to.be.revertedWith(
        "x / y != dx / dy",
      );
    });

    it("Should revert when adding 0 tokens", async () => {
      await expect(amm.addLiquidity(0, 1)).to.be.revertedWith("shares == 0");
      await expect(amm.addLiquidity(1, 0)).to.be.revertedWith("shares == 0");
      await expect(amm.addLiquidity(0, 0)).to.be.revertedWith("shares == 0");
    });
  });

  describe("removeLiquidity()", () => {
    it("Should correctly remove liquidity", async () => {
      const amount0 = 2;
      const amount1 = 2;
      const shares = Math.sqrt(amount0 * amount1);

      await amm.addLiquidity(amount0, amount1);

      await amm.removeLiquidity(shares);
      expect(await token0.balanceOf(owner.address)).to.equal(100);
      expect(await token1.balanceOf(owner.address)).to.equal(100);
      expect(await amm.reserve0()).to.equal(0);
      expect(await amm.reserve1()).to.equal(0);
      expect(await amm.balanceOf(owner.address)).to.equal(0);
    });

    it("Should revert when removing liquidity when totalSupply is zero", async () => {
      await expect(amm.removeLiquidity(1)).to.be.revertedWith(
        "totalSupply == 0",
      );
    });

    it("Should revert when removing liquidity with invalid shares", async () => {
      await amm.addLiquidity(1, 1);

      await expect(amm.removeLiquidity(0)).to.be.revertedWith(
        "amount0 or amount1 == 0",
      );
    });
  });

  describe("swap()", () => {
    beforeEach(async () => {
      await amm.addLiquidity(100, 100);

      await token0.connect(addr1).mint(100);
      await token1.connect(addr1).mint(100);
    });

    it("Should correctly swap tokens", async () => {
      const reserveIn = (await amm.reserve0()).toNumber();
      const reserveOut = (await amm.reserve1()).toNumber();
      const amountIn = 25;
      const amountOutMin = (
        await amm.quote(amountIn, reserveIn, reserveOut)
      ).toNumber();

      await amm.connect(addr1).swap(token0.address, amountIn, amountOutMin);

      expect(await amm.reserve0()).to.equal(reserveIn + amountIn);
      expect(await amm.reserve1()).to.equal(reserveOut - amountOutMin);
      expect(await token0.balanceOf(addr1.address)).to.equal(100 - amountIn);
      expect(await token1.balanceOf(addr1.address)).to.equal(
        100 + amountOutMin,
      );
    });

    it("Should revert with invalid tokenIn", async () => {
      await expect(
        amm.connect(addr1).swap(ethers.constants.AddressZero, 1, 0),
      ).to.be.revertedWith("invalid tokenIn");
    });

    it("Should revert when amountIn is zero", async () => {
      await expect(
        amm.connect(addr1).swap(token0.address, 0, 0),
      ).to.be.revertedWith("amountIn == 0");
    });

    it("Should revert when amountOut is lower than amountOutMin", async () => {
      const amountOutMin = (await amm.quote(10, 100, 100)).add(1); // expected 9
      await expect(
        amm.connect(addr1).swap(token0.address, 10, amountOutMin),
      ).to.be.revertedWith("amountOut < amountOutMin");
    });

    it("Should swap when amountOutMin is zero", async () => {
      const reserveIn = (await amm.reserve0()).toNumber();
      const reserveOut = (await amm.reserve1()).toNumber();
      const amountIn = 25;
      const amountOutMin = (
        await amm.quote(amountIn, reserveIn, reserveOut)
      ).toNumber();

      await amm.connect(addr1).swap(token0.address, amountIn, 0);

      expect(await amm.reserve0()).to.equal(reserveIn + amountIn);
      expect(await amm.reserve1()).to.equal(reserveOut - amountOutMin);
      expect(await token0.balanceOf(addr1.address)).to.equal(100 - amountIn);
      expect(await token1.balanceOf(addr1.address)).to.equal(
        100 + amountOutMin,
      );
    });
  });
});
