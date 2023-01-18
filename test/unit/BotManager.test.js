const {
  time,
  loadFixture,
  impersonateAccount,
} = require("@nomicfoundation/hardhat-network-helpers");

const { expect, assert } = require("chai");

const { networkConfig } = require("../../helper-hardhat-config");

const { network, ethers } = require("hardhat");

describe("Bot Manager Unit test", () => {
  async function deployRandomBots(
    number,
    botManager,
    tokenAddress,
    tokenAddressWBTC
  ) {
    for (let i = 1; i <= number; i++) {
      await botManager.setUpNewBot(
        tokenAddress,
        tokenAddressWBTC,
        10,
        ethers.utils.parseUnits("100", 8),
        ethers.utils.parseUnits("10", 6)
      );
    }
  }

  async function deployManagerFixture() {
    const chainId = network.config.chainId;

    /** GMX  Addresses */
    const positionRouterAddress = networkConfig[chainId]["positionRouter"];
    const vaultAddress = networkConfig[chainId]["vault"];
    const routerAddress = networkConfig[chainId]["router"];

    /** Token Addresses */
    const tokenAddress = networkConfig[chainId]["USDC"];
    const tokenAddressWBTC = networkConfig[chainId]["wBTC"];

    /** Contracts to deploy */

    // 1. Deploy the settings
    const ProjectSettings = await ethers.getContractFactory("ProjectSettings");
    const projectSettings = await ProjectSettings.deploy();

    await projectSettings.initiliazeGMXAddresses(
      routerAddress,
      positionRouterAddress,
      vaultAddress
    );

    // 2. Deploy the Bot Manager contract after deply the tradeHelper implementation
    const TradeHelper = await ethers.getContractFactory("TradeHelper");
    const BotManager = await ethers.getContractFactory("BotManager");

    const tradeHelperImplementaion = await TradeHelper.deploy();

    const botManager = await BotManager.deploy();

    await botManager.setTradeHelperImplemenation(
      tradeHelperImplementaion.address
    );

    await botManager.setProjectSettingAddress(projectSettings.address);

    // 3. deploy a mock priceFeed

    const MockPriceFeed = await ethers.getContractFactory("MockV3Aggregator");
    const mockPriceFeed = await MockPriceFeed.deploy(
      8,
      ethers.utils.parseUnits("1000", 8)
    );

    await botManager.setPriceFeed(tokenAddressWBTC, mockPriceFeed.address);

    const [owner, user, spender] = await ethers.getSigners();

    // 4. send USDC to the owner
    const USDC = await ethers.getContractAt("IERC20", tokenAddress);
    const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

    await impersonateAccount(whaleAddress);
    const impersonatedSigner = await ethers.getSigner(whaleAddress);

    const _balance = await USDC.balanceOf(impersonatedSigner.address);

    await USDC.connect(impersonatedSigner).transfer(owner.address, _balance);
    const _balanceOwner = await USDC.balanceOf(owner.address);

    return {
      mockPriceFeed,
      user,
      owner,
      tokenAddressWBTC,
      tokenAddress,
      botManager,
      spender,
    };
  }

  describe("#setUpNewBot", () => {
    it("should set up a new bot and create a new clone contract", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC } = await loadFixture(
        deployManagerFixture
      );

      await botManager.setUpNewBot(
        tokenAddress,
        tokenAddressWBTC,
        10,
        ethers.utils.parseUnits("100", 8),
        ethers.utils.parseUnits("10", 6)
      );

      const botList = await botManager.getBotList();

      assert.equal(botList.length, 1);
    });
  });

  describe("#activateBot", () => {
    it("should activate the bot and initalize the limit prices", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC } = await loadFixture(
        deployManagerFixture
      );

      await botManager.setUpNewBot(
        tokenAddress,
        tokenAddressWBTC,
        10,
        ethers.utils.parseUnits("100", 8),
        ethers.utils.parseUnits("10", 6)
      );

      const botList = await botManager.getBotList();

      await botManager.activateBot(botList[0]);

      const _setting = await botManager.getBotSetting(botList[0]);

      assert(_setting.longLimitPrice.gt(ethers.constants.Zero));
      assert(_setting.shortLimitPrice.gt(ethers.constants.Zero));

      assert(_setting.isActivated);
    });

    it("should emit an event that the bot is activated", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC } = await loadFixture(
        deployManagerFixture
      );

      await botManager.setUpNewBot(
        tokenAddress,
        tokenAddressWBTC,
        10,
        ethers.utils.parseUnits("100", 8),
        ethers.utils.parseUnits("10", 6)
      );

      const botList = await botManager.getBotList();

      await expect(botManager.activateBot(botList[0]))
        .to.emit(botManager, "BotActivated")
        .withArgs(
          botList[0],
          tokenAddressWBTC,
          ethers.utils.parseUnits("1100", 8),
          ethers.utils.parseUnits("900", 8)
        );
    });
  });
});
