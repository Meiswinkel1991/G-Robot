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
    const tokenAddressWBTC = networkConfig[chainId]["wBTC"];

    const TradeHelper = await ethers.getContractFactory("TradeHelper");
    const ProjectSettings = await ethers.getContractFactory("ProjectSettings");
    const BotManager = await ethers.getContractFactory("BotManager");
    const vaultGMX = await ethers.getContractAt("IVault", vaultAddress);
    const positionRouterGMX = await ethers.getContractAt(
      "IPositionRouter",
      positionRouterAddress
    );

    // 1. Deploy the settings
    const projectSettings = await ProjectSettings.deploy();

    await projectSettings.initiliazeGMXAddresses(
      routerAddress,
      positionRouterAddress,
      vaultAddress
    );

    // 2. Deploy the Router Contract after deply the tradeHelper implementation

    const tradeHelperImplementaion = await TradeHelper.deploy();

    const managerContract = await BotManager.deploy();

    await managerContract.setTradeHelperImplemenation(
      tradeHelperImplementaion.address
    );

    await managerContract.setProjectSettingAddress(projectSettings.address);

    // 3. Deploy a proxy contract for testing
    const gridSize = ethers.utils.parseUnits("100", 30);

    const tradingSize = ethers.utils.parseUnits("10", 6);

    await managerContract.setUpNewBot(
      tokenAddress,
      tokenAddressWBTC,
      2,
      gridSize,
      tradingSize
    );

    const botList = await managerContract.getBotContracts();

    const tradeHelper = await ethers.getContractAt("TradeHelper", botList[0]);

    const [owner, user, spender] = await ethers.getSigners();

    const USDC = await ethers.getContractAt("IERC20", tokenAddress);
    const WBTC = await ethers.getContractAt("IERC20", tokenAddressWBTC);

    let balanceTradeHelper = await USDC.balanceOf(tradeHelper.address);

    if (balanceTradeHelper.eq(ethers.constants.Zero)) {
      const whaleAddress = "0xf89d7b9c864f589bbF53a82105107622B35EaA40";

      await impersonateAccount(whaleAddress);
      const impersonatedSigner = await ethers.getSigner(whaleAddress);

      const _balance = await USDC.balanceOf(impersonatedSigner.address);

      await USDC.connect(impersonatedSigner).transfer(
        tradeHelper.address,
        _balance.div(ethers.BigNumber.from("100000"))
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

    return {
      tradeHelper,
      tokenAddressWETH,
      balanceTradeHelper,
      owner,
      tokenAddressWBTC,
      USDC,
      WBTC,
      vaultGMX,
      tokenAddress,
      positionRouterGMX,
    };
  }

  async function openPosition(tradeHelper) {
    const _amountIn = ethers.utils.parseUnits("100", 6);

    const _deltaSize = ethers.utils.parseUnits("200", 30);

    await tradeHelper.createIncreasePositionRequest(
      true,
      _amountIn,
      _deltaSize
    );
  }

  describe("#swapToIndexToken", () => {
    it("should swap the stable token to the index token", async () => {
      const { tradeHelper, USDC, WBTC } = await loadFixture(
        deployTradeHelperFixture
      );
      console.log("Before swapping Tokens:");
      const stableBalance = await USDC.balanceOf(tradeHelper.address);
      console.log(
        `Balance USDC: ${ethers.utils.formatUnits(stableBalance, 6)}`
      );

      const indexBalance = await WBTC.balanceOf(tradeHelper.address);
      console.log(`Balance wBTC: ${ethers.utils.formatUnits(indexBalance, 8)}`);

      //swap the tokens

      await tradeHelper.swapToIndexToken(stableBalance);

      console.log("After swapping Tokens:");
      const stableBalanceAfter = await USDC.balanceOf(tradeHelper.address);
      console.log(
        `Balance USDC: ${ethers.utils.formatUnits(stableBalanceAfter, 6)}`
      );

      const indexBalanceAfter = await WBTC.balanceOf(tradeHelper.address);
      console.log(
        `Balance wBTC: ${ethers.utils.formatUnits(indexBalanceAfter, 8)}`
      );

      assert(indexBalanceAfter.gt(indexBalance));
      assert(stableBalance.gt(stableBalanceAfter));
    });
  });

  describe("#createLongPosition", () => {
    it("should create a new increase position request", async () => {
      const { tradeHelper } = await loadFixture(deployTradeHelperFixture);

      await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

      //open a request with a leverage of 10
      await expect(tradeHelper.createLongPosition(10, 100)).to.emit(
        tradeHelper,
        "RequestLongPosition"
      );
    });

    it("should update the last position request", async () => {
      const { tradeHelper } = await loadFixture(deployTradeHelperFixture);

      await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

      await tradeHelper.createLongPosition(10, 100);

      const request = await tradeHelper.getLastRequest(true);

      console.log(request);
    });
  });

  describe("#executePosition", () => {
    it("should execute the request after 181 seconds", async () => {
      const { tradeHelper, vaultGMX } = await loadFixture(
        deployTradeHelperFixture
      );

      await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

      await tradeHelper.createLongPosition(10, 100);

      const request = await tradeHelper.getLastRequest(true);

      // execute the request after 181 seconds

      await time.increase(181);

      await tradeHelper.executePosition(true);
    });
  });
});
