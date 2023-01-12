const { network, run } = require("hardhat");

const { deployTradeHelper } = require("./deployTradeHelper");

async function main() {
  await run("compile");

  console.log(`Start deploying contracts to ${network.name}`);
  console.log("================================");
  await deployTradeHelper();

  console.log("Finished Deploying!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
