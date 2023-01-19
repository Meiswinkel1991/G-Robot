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

    const botList = await managerContract.getBotList();

    const tradeHelper = await ethers.getContractAt("TradeHelper", botList[0]);

    const [owner, user, spender] = await ethers.getSigners();

    const USDC = await ethers.getContractAt("IERC20", tokenAddress);
    const WBTC = await ethers.getContractAt("IERC20", tokenAddressWBTC);

    let balanceTradeHelper = await USDC.balanceOf(tradeHelper.address);

    if (balanceTradeHelper.lt(ethers.utils.parseUnits("200", 6))) {
      const whaleAddress = "0xFC2346AD540818d3c24687FA9598253D82D9129C";

      await impersonateAccount(whaleAddress);
      const impersonatedSigner = await ethers.getSigner(whaleAddress);

      const _balance = await USDC.balanceOf(impersonatedSigner.address);

      console.log(
        `Balance whale ${ethers.utils.formatUnits(_balance, 6)} USDC`
      );

      await USDC.connect(impersonatedSigner).transfer(
        tradeHelper.address,
        ethers.utils.parseUnits("200", 6)
      );

      balanceTradeHelper = await USDC.balanceOf(tradeHelper.address);

      console.log(
        `Balance Bot: ${ethers.utils.formatUnits(balanceTradeHelper, 6)}`
      );
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
      const { tradeHelper, USDC } = await loadFixture(deployTradeHelperFixture);

      const balanceUSDC = await USDC.balanceOf(tradeHelper.address);

      console.log(ethers.utils.formatUnits(balanceUSDC, 6));

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

    it("should update the collateral and size of the long position", async () => {
      const { tradeHelper, vaultGMX } = await loadFixture(
        deployTradeHelperFixture
      );

      await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

      await tradeHelper.createLongPosition(10, 100);

      // execute the request after 181 seconds

      await time.increase(181);

      await tradeHelper.executePosition(true);

      const col = await tradeHelper.getCollateral(true);

      console.log(`Collateral Long: ${ethers.utils.formatUnits(col, 30)}`);

      const size = await tradeHelper.getPositionSize(true);

      console.log(`Position Size Long: ${ethers.utils.formatUnits(size, 30)}`);

      const request = await tradeHelper.getLastRequest(true);

      assert(request.size.eq(size));
    });

    describe("#exitLongPosition", () => {
      it("should create a new decrease request", async () => {
        const { tradeHelper, vaultGMX } = await loadFixture(
          deployTradeHelperFixture
        );

        const col = await tradeHelper.getCollateral(true);
        const size = await tradeHelper.getPositionSize(true);

        await tradeHelper.exitLongPosition(col.div(2), size.div(2), 10, 100);
      });

      it("should be executable after 180 seconds", async () => {
        const { tradeHelper, WBTC, vaultGMX, tokenAddressWBTC } =
          await loadFixture(deployTradeHelperFixture);

        await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

        const balanceBitcoin = await WBTC.balanceOf(tradeHelper.address);
        console.log(
          `Balance WBTC: ${ethers.utils.formatUnits(balanceBitcoin, 8)}`
        );

        await tradeHelper.createLongPosition(10, 100);

        // execute the request after 181 seconds

        await time.increase(181);

        await tradeHelper.executePosition(true);

        const col = await tradeHelper.getCollateral(true);
        const size = await tradeHelper.getPositionSize(true);

        await tradeHelper.exitLongPosition(0, size, 10, 100);
        await time.increase(181);
        await tradeHelper.executePosition(true);

        const request = await tradeHelper.getLastRequest(true);

        assert(request.executed);

        const _newCol = await tradeHelper.getCollateral(true);

        console.log(
          `Collateral Long: ${ethers.utils.formatUnits(_newCol, 30)}`
        );

        const _newSize = await tradeHelper.getPositionSize(true);

        console.log(
          `Position Size Long: ${ethers.utils.formatUnits(_newSize, 30)}`
        );

        const balanceBitcoinAfter = await WBTC.balanceOf(tradeHelper.address);
        console.log(
          `Balance WBTC: ${ethers.utils.formatUnits(balanceBitcoinAfter, 8)}`
        );
      });

      it("should decrease the half of the position", async () => {
        const { tradeHelper, WBTC, vaultGMX, USDC } = await loadFixture(
          deployTradeHelperFixture
        );

        const balanceUSDC = await USDC.balanceOf(tradeHelper.address);
        console.log(
          `Balance USDC: ${ethers.utils.formatUnits(balanceUSDC, 6)}`
        );

        await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("100", 6));

        let balanceBitcoin = await WBTC.balanceOf(tradeHelper.address);
        console.log(
          `Balance WBTC: ${ethers.utils.formatUnits(balanceBitcoin, 8)}`
        );

        await tradeHelper.createLongPosition(10, 100);

        // execute the request after 181 seconds

        await time.increase(181);

        await tradeHelper.executePosition(true);

        await time.increase(181);
        await tradeHelper.swapToIndexToken(ethers.utils.parseUnits("40", 6));

        balanceBitcoin = await WBTC.balanceOf(tradeHelper.address);
        console.log(
          `Balance WBTC: ${ethers.utils.formatUnits(balanceBitcoin, 8)}`
        );

        await tradeHelper.createLongPosition(10, 100);

        // execute the request after 181 seconds

        await time.increase(181);

        await tradeHelper.executePosition(true);

        //Start decreasing 100 USDC

        const col = await tradeHelper.getCollateral(true);
        console.log(col);
        const size = await tradeHelper.getPositionSize(true);
        console.log(size);
        await tradeHelper.exitLongPosition(
          ethers.utils.parseUnits("100", 30),
          ethers.utils.parseUnits("1000", 30),
          10,
          100
        );
        await time.increase(181);
        await tradeHelper.executePosition(true);

        const request = await tradeHelper.getLastRequest(true);

        assert(request.executed);

        const _newCol = await tradeHelper.getCollateral(true);

        console.log(
          `Collateral Long: ${ethers.utils.formatUnits(_newCol, 30)}`
        );

        const _newSize = await tradeHelper.getPositionSize(true);

        console.log(
          `Position Size Long: ${ethers.utils.formatUnits(_newSize, 30)}`
        );
      });
    });
  });
});
