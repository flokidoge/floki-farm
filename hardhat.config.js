require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-etherscan");

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.getAddress());
  }
});

module.exports = {
  // This is a sample solc configuration that specifies which version of solc to use
  solidity: {
    version: "0.6.12",
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  networks: {
    // hardhat: {
    //   mining: {
    //     auto: false,
    //     interval: 100      
    //   }
    // },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: { 
        mnemonic: "",
        initialIndex: 1,
        count: 1

      }
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org",
      chainId: 56,
      gas: "auto",
      gasPrice: "auto",
      accounts: {
        mnemonic: "",
        initialIndex: 1,
        count: 1
      }
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ""
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
