const hre = require("hardhat");

async function main() {
  const Treasury = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199";
  const investmentCap = "10000000000000000000";
  const exchangerate = "1000000000";
  const minInvestment = "1000000000000000000";
  const feePercentage = "2";

  // We get the contract to deploy
  const KhuberoToken = await hre.ethers.getContractFactory("KhuberoToken");
  const khuberoToken = await KhuberoToken.deploy(
    Treasury,
    investmentCap,
    exchangerate,
    minInvestment,
    feePercentage
  );

  await khuberoToken.deployed();

  const KBRAddr = khuberoToken.address;

  console.log("KhuberoToken deployed to:", KBRAddr);

  const Staking = await hre.ethers.getContractFactory("Staking");
  const staking = await Staking.deploy(KBRAddr);

  await staking.deployed();

  console.log("Staking deployed to:", staking.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
