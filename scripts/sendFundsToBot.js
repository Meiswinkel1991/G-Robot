const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { getDeployments } = require("../helper-functions");

async function main() {
  const chainId = network.config.chainId;

  const USDCAddress = networkConfig[chainId]["USDC"];

  const USDC = await ethers.getContractAt("IERC20", USDCAddress);

  const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

  await helpers.impersonateAccount(whaleAddress);
  const impersonatedSigner = await ethers.getSigner(whaleAddress);

  const balance = await USDC.balanceOf(impersonatedSigner.address);

  console.log(`Balance of whale: ${ethers.utils.formatUnits(balance, 6)}`);

  const botAddress = getDeployments(chainId)["GridBot"].address;

  await USDC.connect(impersonatedSigner).transfer(botAddress, balance);

  const botBalance = await USDC.balanceOf(botAddress);

  console.log(botBalance);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
