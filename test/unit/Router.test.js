const {
  time,
  loadFixture,
  impersonateAccount,
} = require("@nomicfoundation/hardhat-network-helpers");

const { expect, assert } = require("chai");

const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

const { updateContractData } = require("../../helper-functions");

describe("Router Unit test", () => {
  async function deployRouterFixture() {
    const chainId = network.config.chainId;

    const positionRouterAddress = networkConfig[chainId]["positionRouter"];
    const vaultAddress = networkConfig[chainId]["vault"];
    const routerAddress = networkConfig[chainId]["router"];
    const tokenAddress = networkConfig[chainId]["USDC"];
    const tokenAddressWETH = networkConfig[chainId]["wETH"];
    const tokenAddressWBTC = networkConfig[chainId]["wBTC"];
    const priceFeedAddress = networkConfig[chainId]["priceFeedWBTC"];

    const TradeHelper = await ethers.getContractFactory("TradeHelper");
    const ProjectSettings = await ethers.getContractFactory("ProjectSettings");
    const Router = await ethers.getContractFactory("Router");

    // 1. Deploy the settings
    const projectSettings = await ProjectSettings.deploy();

    await projectSettings.initiliazeGMXAddresses(
      routerAddress,
      positionRouterAddress,
      vaultAddress
    );

    // 2. Deploy the Router Contract after deply the tradeHelper implementation

    const tradeHelperImplementaion = await TradeHelper.deploy();

    const routerContract = await Router.deploy();

    await routerContract.setTradeHelperImplemenation(
      tradeHelperImplementaion.address
    );

    await routerContract.setProjectSettingAddress(projectSettings.address);

    const [owner, user, spender] = await ethers.getSigners();

    return {
      routerContract,
      user,
      owner,
      tokenAddressWBTC,
      tokenAddress,
      priceFeedAddress,
    };
  }

  describe("#setUpNewBot", () => {
    it("should successful set up a new bot", async () => {
      const { routerContract, tokenAddress, tokenAddressWBTC, user } =
        await loadFixture(deployRouterFixture);

      const leverage = 5;
      const tradingSize = ethers.utils.parseUnits("10", 6);
      const gridSize = ethers.utils.parseUnits("1", 8);

      await routerContract
        .connect(user)
        .setUpNewBot(
          tokenAddress,
          tokenAddressWBTC,
          leverage,
          gridSize,
          tradingSize
        );

      const bots = await routerContract.getBotKeyList();

      assert.equal(bots.length, 1);
    });

    it("should return an event after successful setup a new bot", async () => {
      const { routerContract, tokenAddress, tokenAddressWBTC, user } =
        await loadFixture(deployRouterFixture);

      const leverage = 5;
      const tradingSize = ethers.utils.parseUnits("10", 6);
      const gridSize = ethers.utils.parseUnits("1", 8);

      await expect(
        routerContract
          .connect(user)
          .setUpNewBot(
            tokenAddress,
            tokenAddressWBTC,
            leverage,
            gridSize,
            tradingSize
          )
      ).to.emit(routerContract, "BotInitialized");
    });

    it("should faile after set up the same bot twice", async () => {
      const { routerContract, tokenAddress, tokenAddressWBTC, user } =
        await loadFixture(deployRouterFixture);

      const leverage = 5;
      const tradingSize = ethers.utils.parseUnits("10", 6);
      const gridSize = ethers.utils.parseUnits("1", 8);

      await routerContract
        .connect(user)
        .setUpNewBot(
          tokenAddress,
          tokenAddressWBTC,
          leverage,
          gridSize,
          tradingSize
        );

      await expect(
        routerContract
          .connect(user)
          .setUpNewBot(
            tokenAddress,
            tokenAddressWBTC,
            leverage,
            gridSize,
            tradingSize
          )
      ).to.be.revertedWith("Router: Bot already exist");
    });
  });

  describe("#setPriceFeed", () => {
    it("should successful update the price feed of the token", async () => {
      const { routerContract, tokenAddressWBTC, priceFeedAddress } =
        await loadFixture(deployRouterFixture);

      await routerContract.setPriceFeed(tokenAddressWBTC, priceFeedAddress);

      const _priceFeed = await routerContract.getPriceFeed(tokenAddressWBTC);

      assert.equal(_priceFeed, priceFeedAddress);
    });

    it("should emit an event after updating the priceFeed", async () => {
      const { routerContract, tokenAddressWBTC, priceFeedAddress } =
        await loadFixture(deployRouterFixture);

      await expect(
        routerContract.setPriceFeed(tokenAddressWBTC, priceFeedAddress)
      ).to.emit(routerContract, "PriceFeedUpdated");
    });
  });

  describe("#activateBot", () => {
    it("should successful activate the bot", async () => {
      const {
        routerContract,
        tokenAddress,
        tokenAddressWBTC,
        user,
        priceFeedAddress,
      } = await loadFixture(deployRouterFixture);

      await routerContract.setPriceFeed(tokenAddressWBTC, priceFeedAddress);

      const leverage = 5;
      const tradingSize = ethers.utils.parseUnits("10", 6);
      const gridSize = ethers.utils.parseUnits("100", 8);

      await routerContract
        .connect(user)
        .setUpNewBot(
          tokenAddress,
          tokenAddressWBTC,
          leverage,
          tradingSize,
          gridSize
        );

      const bots = await routerContract.getBotKeyList();

      await routerContract.connect(user).activateBot(bots[0]);

      const setting = await routerContract.getBotSetting(bots[0]);

      const priceDelta = setting.longLimitPrice.sub(setting.shortLimitPrice);

      assert(gridSize.eq(priceDelta.div(2)));

      assert(setting.isActivated === true);
    });
  });
});
