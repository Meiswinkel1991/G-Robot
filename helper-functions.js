const fs = require("fs");
const { run, network, ethers, artifacts } = require("hardhat");
const {
  networkConfig,
  deployedContractsPath,
} = require("./helper-hardhat-config");

const updateContractData = async (contract, chainId, contractName) => {
  const _address = contract.address;

  const filePath = deployedContractsPath;

  const deployedContracts = JSON.parse(fs.readFileSync(filePath, "utf-8"));

  const _abi = (await artifacts.readArtifact(contractName)).abi;

  if (chainId in deployedContracts) {
    if (contractName in deployedContracts[chainId]) {
      deployedContracts[chainId][contractName]["abi"] = _abi;
      deployedContracts[chainId][contractName]["address"] = _address;
    } else {
      deployedContracts[chainId][contractName] = {
        abi: _abi,
        address: _address,
      };
    }
  } else {
    const contractData = {};
    contractData[contractName] = {
      abi: _abi,
      address: _address,
    };

    deployedContracts[chainId] = contractData;
  }

  fs.writeFileSync(filePath, JSON.stringify(deployedContracts));
};

const getDeployments = (chainId) => {
  const filePath = deployedContractsPath;
  const deployedContracts = JSON.parse(fs.readFileSync(filePath, "utf-8"));

  return deployedContracts[chainId];
};

module.exports = {
  updateContractData,
  getDeployments,
};
