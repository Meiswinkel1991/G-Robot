const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

async function main() {
  const chainId = network.config.chainId;

  const USDCAddress = networkConfig[chainId]["USDC"];

  const USDC = await ethers.getContractAt("IERC20", USDCAddress);

  const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

  await helpers.impersonateAccount(whaleAddress);
  const impersonatedSigner = await ethers.getSigner(whaleAddress);

  const balance = await USDC.balanceOf(impersonatedSigner.address);

  console.log(`Balance of whale: ${ethers.utils.formatUnits(balance, 8)}`);

  const botAddress = await USDC.connect(impersonatedSigner).transfer(
    signer.address,
    balance
  );

  const botBalance = await USDC.balanceOf(
    "0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB"
  );

  console.log(botBalance);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
