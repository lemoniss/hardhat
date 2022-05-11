import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import { ethers } from "hardhat";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (_, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("deployNFT", "Deploy NFT contract", async (_, hre) => {
  const accounts = await hre.ethers.getSigners();
  const mintPrice = hre.ethers.utils.parseEther("0.0001")
  return hre.ethers
    .getContractFactory("MusitNFT", accounts[0])
    .then((contractFactory) => contractFactory.deploy(mintPrice))
    .then((result) => {
      console.log(result.address);
    });
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const getApiKey = (provider: string): string | undefined => {
  if (provider === "alchemy") return process.env.ALCHEMY_API_KEY;
  else if (provider === "infura") return process.env.INFURA_API_KEY;
  else return "";
};

const getURL = (provider: string, network: string): string => {
  const apiKey = getApiKey(provider);
  if (provider && apiKey) {
    if (provider == "alchemy") {
      return `https://eth-${network}.alchemyapi.io/v2/${apiKey}`;
    } else if (provider == "infura") {
      return `https://${network}.infura.io/v3/${apiKey}`;
    } else return "";
  } else return "";
};

const getPrivateKey = (): string[] => {
  return process.env.PRIVATE_KEY !== undefined
    ? [process.env.PRIVATE_KEY]
    : ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"];
};



const config: HardhatUserConfig = {
  solidity: "0.8.4",
  defaultNetwork: "localhost",
  networks: {
    ropsten: {
      url: getURL("alchemy", "ropsten"),
      accounts: getPrivateKey(),
    },
    rinkeby: {
      url: getURL("alchemy", "rinkeby"),
      accounts: getPrivateKey(),
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
