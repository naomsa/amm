import { ethers } from "hardhat";

async function main() {
  const token0 = await (await ethers.getContractFactory("MockERC20")).deploy();
  const token1 = await (await ethers.getContractFactory("MockERC20")).deploy();

  const amm = await (
    await ethers.getContractFactory("AMM")
  ).deploy(token0.address, token1.address);

  await amm.deployed();

  console.log("token0:", token0.address);
  console.log("token1:", token1.address);
  console.log("amm:", amm.address);
}

main().catch((error) => {
  console.log(error);
  process.exit(1);
});
