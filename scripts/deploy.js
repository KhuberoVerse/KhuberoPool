// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

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

  console.log("KhuberoToken deployed to:", khuberoToken.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
