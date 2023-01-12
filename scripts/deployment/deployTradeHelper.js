const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

const { updateContractData } = require("../../helper-functions");

async function deployTradeHelper() {
  const chainId = network.config.chainId;

  const positionRouterAddress = networkConfig[chainId]["positionRouter"];
  const vaultAddress = networkConfig[chainId]["vault"];

  const tokenAddress = networkConfig[chainId]["USDC"];

  const TradeHelper = await ethers.getContractFactory("TradeHelper");
  const tradeHelper = await TradeHelper.deploy(
    positionRouterAddress,
    vaultAddress,
    tokenAddress
  );

  await tradeHelper.deployed();

  console.log(`Trade Helper deployed to ${tradeHelper.address}`);

  await updateContractData(tradeHelper, chainId, "TradeHelper");
}

module.exports = { deployTradeHelper };
