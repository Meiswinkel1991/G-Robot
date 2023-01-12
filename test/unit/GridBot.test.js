const {
  time,
  loadFixture,
  impersonateAccount,
} = require("@nomicfoundation/hardhat-network-helpers");

const { expect, assert } = require("chai");

const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

const { updateContractData } = require("../../helper-functions");

describe("GridBot Unit test", () => {
  async function deployGridBotFixture() {
    const chainId = network.config.chainId;

    const positionRouterAddress = networkConfig[chainId]["positionRouter"];
    const vaultAddress = networkConfig[chainId]["vault"];
    const routerAddress = networkConfig[chainId]["router"];
    const tokenAddress = networkConfig[chainId]["USDC"];
    const tokenAddressWETH = networkConfig[chainId]["wETH"];

    const GridBot = await ethers.getContractFactory("GridBot");
    const gridBot = await GridBot.deploy(
      positionRouterAddress,
      vaultAddress,
      routerAddress,
      tokenAddress,
      tokenAddressWETH
    );

    const [owner, user, spender] = await ethers.getSigners();

    //send funds to bot Contract if needed
    const USDC = await ethers.getContractAt("IERC20", tokenAddress);

    let balanceBot = await USDC.balanceOf(gridBot.address);

    if (balanceBot.eq(ethers.constants.Zero)) {
      const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

      await impersonateAccount(whaleAddress);
      const impersonatedSigner = await ethers.getSigner(whaleAddress);

      const balance = await USDC.balanceOf(impersonatedSigner.address);

      await USDC.connect(impersonatedSigner).transfer(
        gridBot.address,
        balance.div(ethers.BigNumber.from("100"))
      );

      balanceBot = await USDC.balanceOf(gridBot.address);
    }

    let etherBalanceBot = await ethers.provider.getBalance(gridBot.address);

    if (etherBalanceBot.lt(ethers.utils.parseEther("1"))) {
      const tx = {
        to: gridBot.address,
        value: ethers.utils.parseEther("1"),
      };
      await spender.sendTransaction(tx);
    }

    return { gridBot, owner, user, balanceBot };
  }

  describe("#addToPosition", () => {
    it("should open and execute a new position on gmx protocol", async () => {
      const { gridBot, balanceBot } = await loadFixture(deployGridBotFixture);

      const _amountIn = balanceBot;

      console.log(`Add following USDC Amount ${_amountIn}`);

      const positionSize = _amountIn.mul(ethers.constants.Two);

      console.log(`Position Leverage: 2 ; Position Size:${positionSize}`);

      await gridBot.addToPosition(_amountIn, positionSize);

      const positions = await gridBot.getPositions();

      console.log(`Open a new long position:`);
      console.log(`Collateral Token: ${positions[0].collateralToken}`);
      console.log(`Index Token: ${positions[0].indexToken}`);
      console.log(`Position Key: ${positions[0].key}`);

      await time.increase(181);

      await gridBot.executePosition(positions[0].key);

      const position = await gridBot.getPositionInfo(0);

      const _positionSize = position[0].div(
        ethers.BigNumber.from("10").pow(24)
      );

      assert(_positionSize.eq(positionSize));
    });

    it("should not have an open position before a action", async () => {
      const { gridBot, balanceBot } = await loadFixture(deployGridBotFixture);

      const _amountIn = balanceBot;

      console.log(`Add following USDC Amount ${_amountIn}`);

      const positionSize = _amountIn.mul(ethers.constants.Two);

      console.log(`Position Leverage: 2 ; Position Size:${positionSize}`);

      await gridBot.addToPosition(_amountIn, positionSize);

      const position = await gridBot.getPositionInfo(0);

      assert(position[7].eq(ethers.constants.Zero));
    });
  });
});
