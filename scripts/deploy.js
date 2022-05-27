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

  // We get the contract to deploy
  const KhuberoToken = await hre.ethers.getContractFactory("KhuberoToken");
  const khuberoToken = await KhuberoToken.deploy();

  await khuberoToken.deployed();

  console.log("KhuberoToken deployed to:", khuberoToken.address);

  const TREASURY = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199";

  const Pool = await hre.ethers.getContractFactory("Pool");
  const pool = await Pool.deploy(
    TREASURY,
    khuberoToken.address,
    "10000000000000000000",
    "10000",
    "1000000000000000000",
    "2"
  );

  await pool.deployed();

  console.log("Pool deployed to:", pool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
