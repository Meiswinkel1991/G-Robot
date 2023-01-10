// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { networkConfig } = require("../helper-hardhat-config");

const { network, ethers } = require("hardhat");

async function main() {
  const chainId = network.config.chainId;

  console.log(chainId);
  console.log(networkConfig[chainId]);

  const routerAddress = networkConfig[chainId]["router"];
  const vaultAddress = networkConfig[chainId]["vault"];
  const tokenAddress = networkConfig[chainId]["USDC"];

  const GridBot = await ethers.getContractFactory("GridBot");
  const gridBot = await GridBot.deploy(
    routerAddress,
    vaultAddress,
    tokenAddress
  );

  await gridBot.deployed();

  console.log(`Grid Bot deployed to ${gridBot.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
