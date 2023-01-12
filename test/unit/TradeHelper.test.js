const {
  time,
  loadFixture,
  impersonateAccount,
} = require("@nomicfoundation/hardhat-network-helpers");

const { expect, assert } = require("chai");

const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

const { updateContractData } = require("../../helper-functions");

describe("TradeHelper Unit test", () => {
  async function deployTradeHelperFixture() {
    const chainId = network.config.chainId;

    const positionRouterAddress = networkConfig[chainId]["positionRouter"];
    const vaultAddress = networkConfig[chainId]["vault"];
    const routerAddress = networkConfig[chainId]["router"];
    const tokenAddress = networkConfig[chainId]["USDC"];
    const tokenAddressWETH = networkConfig[chainId]["wETH"];

    const TradeHelper = await ethers.getContractFactory("TradeHelper");

    const tradeHelper = await TradeHelper.deploy(
      routerAddress,
      positionRouterAddress,
      vaultAddress,
      tokenAddress
    );

    const [owner, user, spender] = await ethers.getSigners();

    const USDC = await ethers.getContractAt("IERC20", tokenAddress);

    let balanceTradeHelper = await USDC.balanceOf(tradeHelper.address);

    if (balanceTradeHelper.eq(ethers.constants.Zero)) {
      const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

      await impersonateAccount(whaleAddress);
      const impersonatedSigner = await ethers.getSigner(whaleAddress);

      const _balance = await USDC.balanceOf(impersonatedSigner.address);

      await USDC.connect(impersonatedSigner).transfer(
        tradeHelper.address,
        _balance.div(ethers.BigNumber.from("1000"))
      );

      balanceTradeHelper = await USDC.balanceOf(tradeHelper.address);
    }

    let etherBalaceHelper = await ethers.provider.getBalance(
      tradeHelper.address
    );

    if (etherBalaceHelper.lt(ethers.utils.parseEther("1"))) {
      const tx = {
        to: tradeHelper.address,
        value: ethers.utils.parseEther("1"),
      };
      await spender.sendTransaction(tx);
    }

    return { tradeHelper, tokenAddressWETH, balanceTradeHelper, owner };
  }

  describe("#createIncreasePositionRequest", () => {
    it("it should successfull create a new Increase Request", async () => {
      const { tradeHelper, balanceTradeHelper, tokenAddressWETH } =
        await loadFixture(deployTradeHelperFixture);

      const _amountIn = balanceTradeHelper;

      console.log(
        `Add following Amount as collateral: ${ethers.utils.formatUnits(
          _amountIn,
          6
        )} USDC`
      );

      const _leverage = 2;

      console.log(`Leverage: ${_leverage}`);

      const positionSize = _amountIn.mul(_leverage);

      console.log(
        `Get PositionSize: ${ethers.utils.formatUnits(positionSize, 6)} $`
      );

      await tradeHelper.createIncreasePositionRequest(
        tokenAddressWETH,
        _amountIn,
        positionSize,
        true
      );

      const positions = await tradeHelper.getPositions();

      assert.equal(positions.length === 1);
    });
  });
});
