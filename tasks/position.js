task("position", "Prints an account's position on GMX").setAction(
  async (taskArgs, hre) => {
    const { getDeployments } = require("../helper-functions");

    //TODO: Write Task to control the positions

    const account = hre.ethers.utils.getAddress(taskArgs.account);

    const chainId = hre.network.config.chainId;

    const botAddress = getDeployments(chainId)["GridBot"].address;

    const bot = await ethers.getContractAt("GridBot", botAddress);

    const position = await bot.getPositionInfo(0);
    console.log(position);
  }
);

module.exports = {};
