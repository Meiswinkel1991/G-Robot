const { ethers } = require("hardhat");

async function main() {
  const gridBot = await ethers.getContractAt(
    "GridBot",
    "0x95401dc811bb5740090279Ba06cfA8fcF6113778"
  );

  await gridBot.addLimitOrder(
    "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    true,
    ethers.utils.parseEther("1"),
    5
  );

  const _order = await gridBot.getLimitOrder(0);

  console.log(_order);

  const vault = await ethers.getContractAt(
    "IVault",
    "0x489ee077994B6658eAfA855C308275EAd8097C4A"
  );

  const price = await vault.getMaxPrice(
    "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
  );
  console.log(price);

  await gridBot.openPosition(_order);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
