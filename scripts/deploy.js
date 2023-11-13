// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // TO DO change this to the actual addressess
  const FoundationAddress = '0x1234567890123456789012345678901234567890';
  const CLDAddress = '0xfc84c3dc9898e186ad4b85734100e951e3bcb68c';

  console.log('Deploying Winslow_Core');
  const core = await ethers.deployContract("Winslow_Core_V1", []);
  await core.waitForDeployment();
  const coreAddr = await core.getAddress();
  console.log(
    `Core deployed in ${coreAddr}`
  );

  console.log('Deploying Winslow_Treasury');
  const treasury = await ethers.deployContract('Winslow_Treasury_V1', [core.getAddress(), CLDAddress]);
  await treasury.waitForDeployment();
  console.log(
    `Treasury deployed in ${await treasury.getAddress()}`
  );

  console.log('Deploying Winslow_Voting');
  const voting = await ethers.deployContract('Winslow_Voting_V1', [
    core.getAddress(),
    1000, // ExecutorCut in bps
    1000 // BurnCut in bps
  ]);
  await voting.waitForDeployment();
  console.log(
    `Voting deployed in ${await voting.getAddress()}`
  );

  console.log('Deploying Winslow_SaleFactory');
  const saleFactoy = await ethers.deployContract('SaleFactoryV2', [core.getAddress()]);
  await saleFactoy.waitForDeployment();
  console.log(
    `SaleFactory deployed in ${await saleFactoy.getAddress()}`
  );

  await core.SetInitialContracts(
    treasury.getAddress(),
    voting.getAddress(),
    saleFactoy.getAddress(),
    FoundationAddress
  );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
