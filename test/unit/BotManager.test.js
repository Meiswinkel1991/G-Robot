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

    const [owner, user, badActor, fakeBot] = await ethers.getSigners();

    // 4. send USDC to the owner
    const USDC = await ethers.getContractAt("IERC20", tokenAddress);
    const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

    await impersonateAccount(whaleAddress);
    const impersonatedSigner = await ethers.getSigner(whaleAddress);

    const _balance = await USDC.balanceOf(impersonatedSigner.address);

    await USDC.connect(impersonatedSigner).transfer(owner.address, _balance);

    return {
      mockPriceFeed,
      user,
      owner,
      tokenAddressWBTC,
      tokenAddress,
      botManager,
      badActor,
      fakeBot,
      USDC,
    };
  }

  async function activateNewBot(botManager, tokenAddressWBTC, tokenAddress) {
    await botManager.setUpNewBot(
      tokenAddress,
      tokenAddressWBTC,
      10,
      ethers.utils.parseUnits("100", 8),
      ethers.utils.parseUnits("10", 6)
    );

    const botList = await botManager.getBotList();
    const newBot = botList[botList.length - 1];

    await botManager.activateBot(newBot);

    return newBot;
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

    it("should fail if the bot is already activated", async () => {
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

      await expect(botManager.activateBot(botList[0])).to.revertedWith(
        "BotManager: Bot already activated"
      );
    });

    it("should fail if not the owner tries to activate the bot", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC, badActor } =
        await loadFixture(deployManagerFixture);

      await botManager.setUpNewBot(
        tokenAddress,
        tokenAddressWBTC,
        10,
        ethers.utils.parseUnits("100", 8),
        ethers.utils.parseUnits("10", 6)
      );

      const botList = await botManager.getBotList();

      await expect(
        botManager.connect(badActor).activateBot(botList[0])
      ).to.revertedWith("BotManager: Not the owner of the bot");
    });

    it("should fail if the called contract is not a bot", async () => {
      const { botManager, fakeBot } = await loadFixture(deployManagerFixture);

      await expect(botManager.activateBot(fakeBot.address)).to.revertedWith(
        "BotManager: Not a bot contract"
      );
    });
  });

  describe("#checkupKeep", () => {
    it("should return false when no limits are reached", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC } = await loadFixture(
        deployManagerFixture
      );

      const botAddress = await activateNewBot(
        botManager,
        tokenAddressWBTC,
        tokenAddress
      );

      const answer = await botManager.checkUpkeep("0x");

      assert(!answer.upkeepNeeded);
    });

    it("should return true if the price breaks through the limitPrices", async () => {
      const { botManager, tokenAddress, tokenAddressWBTC, mockPriceFeed } =
        await loadFixture(deployManagerFixture);

      const botAddress = await activateNewBot(
        botManager,
        tokenAddressWBTC,
        tokenAddress
      );

      // set the price higher than 1200 USD

      await mockPriceFeed.updateAnswer(ethers.utils.parseUnits("1200", 8));

      const answer = await botManager.checkUpkeep("0x");

      assert(answer.upkeepNeeded);
    });
  });

  describe("#performUpkeep", () => {
    it("should create a new request if the checkUpkeeper is successfull", async () => {
      const {
        botManager,
        tokenAddress,
        tokenAddressWBTC,
        mockPriceFeed,
        USDC,
        owner,
      } = await loadFixture(deployManagerFixture);

      const botAddress = await activateNewBot(
        botManager,
        tokenAddressWBTC,
        tokenAddress
      );

      const tx = {
        to: botAddress,
        value: ethers.utils.parseEther("1"),
      };

      await owner.sendTransaction(tx);

      const balanceETH = await ethers.provider.getBalance(botAddress);
      console.log(`Bot Ether balance: ${ethers.utils.formatEther(balanceETH)}`);

      // set the price higher than 1200 USD

      await mockPriceFeed.updateAnswer(ethers.utils.parseUnits("1200", 8));

      // should send USDC to bot

      await USDC.transfer(botAddress, ethers.utils.parseUnits("1000", 6));

      const answer = await botManager.checkUpkeep("0x");

      // use the performUpkeep to create a new long position

      await botManager.performUpkeep(answer.performData);

      const bot = await ethers.getContractAt("TradeHelper", botAddress);

      const lastLongRequest = await bot.getLastRequest(true);

      assert(lastLongRequest.increase);
      assert(!lastLongRequest.executed);
      assert(
        lastLongRequest.limitTrigger.eq(ethers.utils.parseUnits("1100", 8))
      );
    });
  });
});
