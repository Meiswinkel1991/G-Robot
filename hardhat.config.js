require("@nomicfoundation/hardhat-toolbox");
require("./tasks");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      hardfork: "merge",
      //If you want to do some forking set `enabled` to true
      forking: {
        url: `${process.env.ARBITRUM_URL}`,
        //blockNumber: FORKING_BLOCK_NUMBER,
        enabled: true,
      },
      chainId: 31337,
    },
    localhost: {
      forking: {
        url: `${process.env.ARBITRUM_URL}`,
        //blockNumber: FORKING_BLOCK_NUMBER,
        enabled: true,
      },
      chainId: 31337,
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
};
