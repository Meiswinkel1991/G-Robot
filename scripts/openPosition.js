const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

async function main() {
  const routerAddress = networkConfig[network.config.chainId]["positionRouter"];

  const positionRouter = await ethers.getContractAt(
    "IPositionRouter",
    routerAddress
  );

  const chainId = network.config.chainId;

  const USDCAddress = networkConfig[chainId]["USDC"];
  const wETHAddress = networkConfig[chainId]["wETH"];

  const sizeDelta = ethers.utils.parseEther("5000");

  const vaultAddress = networkConfig[chainId]["vault"];
  const vaultContract = await ethers.getContractAt("IVault", vaultAddress);

  const maxPrice = await vaultContract.getMaxPrice(wETHAddress);

  const executionFee = 100000000000000;

  console.log(maxPrice);

  // await USDC.connect(signer).approve(routerAddress, amountIn);

  // await positionRouter.createIncreasePosition(
  //   [USDCAddress],
  //   wETHAddress,
  //   amountIn,
  //   0,
  //   sizeDelta,
  //   true,
  //   maxPrice,
  //   executionFee,
  //   ethers.utils.formatBytes32String(""),
  //   ethers.constants.AddressZero,
  //   { value: executionFee }
  // );

  const botAddress = "0x84eA74d481Ee0A5332c457a4d796187F6Ba67fEB";

  const bot = await ethers.getContractAt("GridBot", botAddress);

  await USDC.connect(signer).transfer(bot.address, amountIn);

  const botBalance = await USDC.balanceOf(bot.address);

  let tx = {
    to: bot.address,
    // Convert currency unit from ether to wei
    value: 200000000000000,
  };
  await signer.sendTransaction(tx);

  console.log(botBalance);

  console.log("start position");
  await bot.openPosition();

  const key = await bot.getTrxKey();

  console.log(key);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
