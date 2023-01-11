const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");
const helpers = require("@nomicfoundation/hardhat-network-helpers");
const { getDeployments } = require("../helper-functions");

async function main() {
  const chainId = network.config.chainId;

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

  const botAddress = getDeployments(chainId)["GridBot"].address;

  console.log(botAddress);

  const bot = await ethers.getContractAt("GridBot", botAddress);

  const signer = await ethers.getSigner();

  const tx = {
    to: bot.address,
    value: ethers.utils.parseEther("2"),
  };
  await signer.sendTransaction(tx);

  const _balance = await ethers.provider.getBalance(bot.address);

  console.log(_balance);

  const USDCAddress = networkConfig[chainId]["USDC"];
  const USDC = await ethers.getContractAt("IERC20Metadata", USDCAddress);

  const botBalanceUSDC = await USDC.balanceOf(bot.address);

  const _amountIn = botBalanceUSDC.div(ethers.BigNumber.from("100"));
  console.log(_amountIn);

  const _leverage = 1;

  console.log(`Add following USDC Amount ${_amountIn}`);

  await bot.openPosition(_amountIn, _leverage);

  const key = await bot.getTrxKey();

  await helpers.time.increase(181);

  await bot.executePosition(key);

  const position = await bot.getPositionInfo(0);

  console.log(position);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
