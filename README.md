# GMX Grid Trading Bot

This bot tries to execute a grid trading strategy on the protocol GMX.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

## Process

1. setupNewBot

- new Bot will be create with the settings
- a TradeHelper contract will be deolyed for the bot

2. activateBot

- activate the bot. It is only possible if the caller is the owner
- initialize the limits for opening a short or long position

3. checkUpkeep

4. performUpkeep
