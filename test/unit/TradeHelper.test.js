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
    const Router = await ethers.getContractFactory("Router");
    const vaultGMX = await ethers.getContractAt("IVault", vaultAddress);

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

    // 3. Deploy a proxy contract for testing
    const gridSize = ethers.utils.parseUnits("100", 30);

    const tradingSize = ethers.utils.parseUnits("10", 6);

    await routerContract.setUpNewBot(
      tokenAddress,
      tokenAddressWBTC,
      2,
      gridSize,
      tradingSize
    );

    const botList = await routerContract.getBotKeyList();

    const botInfo = await routerContract.getBotSetting(botList[0]);

    const tradeHelper = await ethers.getContractAt(
      "TradeHelper",
      botInfo.contractAddress
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
      vaultGMX,
      tokenAddress,
    };
  }

  async function openPosition(tradeHelper) {
    const _amountIn = ethers.utils.parseUnits("10", 6);

    const _deltaSize = ethers.utils.parseUnits("20", 30);

    await tradeHelper.createIncreasePositionRequest(
      true,
      _amountIn,
      _deltaSize
    );
  }

  describe("#createIncreasePositionRequest", () => {
    it("should successfull create a new long Increase Request", async () => {
      const { tradeHelper, balanceTradeHelper } = await loadFixture(
        deployTradeHelperFixture
      );

      const _amountIn = ethers.utils.parseUnits("10", 6);

      const _deltaSize = ethers.utils.parseUnits("20", 30);

      await tradeHelper.createIncreasePositionRequest(
        true,
        _amountIn,
        _deltaSize
      );

      const positionRequest = await tradeHelper.getlastPositionRequest(true);

      assert.equal(positionRequest.executed, false);
      assert(positionRequest.amount.gt(ethers.constants.Zero));
    });

    it("should succesfull create a new short Increase request", async () => {
      const { tradeHelper } = await loadFixture(deployTradeHelperFixture);

      const _amountIn = ethers.utils.parseUnits("10", 6);

      const _deltaSize = ethers.utils.parseUnits("20", 30);

      await tradeHelper.createIncreasePositionRequest(
        false,
        _amountIn,
        _deltaSize
      );

      const positionRequest = await tradeHelper.getlastPositionRequest(false);

      assert.equal(positionRequest.executed, false);
      assert(positionRequest.amount.gt(ethers.constants.Zero));
    });
  });

  describe("#executePosition", () => {
    it("successfully execute the position if the keeper doesn't executed", async () => {
      const { tradeHelper, balanceTradeHelper } = await loadFixture(
        deployTradeHelperFixture
      );

      await openPosition(tradeHelper);

      await time.increase(181);

      await tradeHelper.executePosition(true);

      const request = await tradeHelper.getlastPositionRequest(true);

      assert.equal(request.executed, true);
    });
  });

  describe("#createDecreaseRequest", () => {
    it("it should successfull create a new Decrease Request", async () => {
      const { tradeHelper, tokenAddressWBTC, balanceTradeHelper, USDC } =
        await loadFixture(deployTradeHelperFixture);

      await openPosition(tradeHelper);

      await time.increase(181);

      await tradeHelper.executePosition(true);

      //start decreasing actual position

      const balnaceBefore = await USDC.balanceOf(tradeHelper.address);

      const sizeDecrease = ethers.utils.parseUnits("10", 6);
      await tradeHelper.createDecreasePositionRequest(true, 0, sizeDecrease);

      const request = await tradeHelper.getlastPositionRequest(true);

      assert.equal(request.executed, false);
      assert.equal(request.increase, false);
    });

    it("should close the total position", async () => {
      const { tradeHelper, vaultGMX, tokenAddress, tokenAddressWBTC, owner } =
        await loadFixture(deployTradeHelperFixture);

      await openPosition(tradeHelper);

      await time.increase(181);

      await tradeHelper.executePosition(true);

      //start decreasing actual position
      let position = await vaultGMX.getPosition(
        tradeHelper.address,
        tokenAddressWBTC,
        tokenAddressWBTC,
        true
      );

      await tradeHelper.createDecreasePositionRequest(
        true,
        position[1],
        position[0]
      );

      const request = await tradeHelper.getlastPositionRequest(true);

      console.log(request);
      await time.increase(181);

      await tradeHelper.executePosition(true);

      position = await vaultGMX.getPosition(
        tradeHelper.address,
        tokenAddressWBTC,
        tokenAddressWBTC,
        true
      );

      console.log(position);
    });
  });
});
