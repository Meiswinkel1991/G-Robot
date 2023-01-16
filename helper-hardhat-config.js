const networkConfig = {
  42161: {
    positionRouter: "0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868",
    router: "0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064",
    vault: "0x489ee077994B6658eAfA855C308275EAd8097C4A",
    USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    wETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    wBTC: "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
    priceFeedWBTC: "0xd0C7101eACbB49F3deCcCc166d238410D6D46d57",
  },
  31337: {
    positionRouter: "0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868",
    router: "0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064",
    vault: "0x489ee077994B6658eAfA855C308275EAd8097C4A",
    USDC: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    wETH: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    wBTC: "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f",
    priceFeedWBTC: "0xd0C7101eACbB49F3deCcCc166d238410D6D46d57",
  },
};

const deployedContractsPath = "./deployments/deployedContracts.json";

module.exports = { networkConfig, deployedContractsPath };
