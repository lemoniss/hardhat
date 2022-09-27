import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import { ethers } from "hardhat";

dotenv.config();

const infuraKey = 'd97f4633a7ca407ebdc8a3a447d99863';

// const ownerAddress = ['0x7072bE4997CEF6a6c2758479f6565Be45c3b5E50'];
// const ownerAddress = ['0x913C770f77F0aaae8BA94F29492a6784D16e1DA1'];

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (_, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// task("deployNFT", "Deploy NFT contract", async (_, hre) => {
//   const accounts = await hre.ethers.getSigners();
//   const mintPrice = hre.ethers.utils.parseEther("0.0001")
//   return hre.ethers
//     .getContractFactory("MillimxNft", accounts[0])
//     // .getContractFactory('MillimxNft', ownerAddress)
//     .then((contractFactory) => contractFactory.deploy(mintPrice))
//     .then((result) => {
//       console.log(result.address);
//     });
// })

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

// const getApiKey = (provider: string): string | undefined => {
//   if (provider === "alchemy") return process.env.ALCHEMY_API_KEY;
//   else if (provider === "infura") return infuraKey;
//   else return "";
// };

// const getURL = (provider: string, network: string): string => {
//   const apiKey = getApiKey(provider);
//   if (provider && apiKey) {
//     if (provider == "alchemy") {
//       return `https://eth-${network}.alchemyapi.io/v2/${apiKey}`;
//     } else if (provider == "infura") {
//       return `https://${network}.infura.io/v3/${apiKey}`;
//     } else return "";
//   } else return "";
// };

const getPrivateKey = (): string[] => {
  // return process.env.PRIVATE_KEY !== undefined
  //   ? [process.env.PRIVATE_KEY]
  //   : ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"];
  // return ['765e11be658a3afb69148f07c6a42298f78fde029c2dcafa01809d2503b6f294'];
  return ['d6211af3767992685044516a1f9b83bc7593ac503e44087c677377d0ea2759fc'];
};



const config: HardhatUserConfig = {
  solidity: "0.8.4",
  defaultNetwork: "localhost",
  networks: {
    ropsten: {
      // url: getURL("infura", "ropsten"),
      url: "https://sparkling-little-lake.ropsten.quiknode.pro/f3003581158bf6d00b05698c6ee60989a8ab3ba7/",
      accounts: getPrivateKey(),
    },
    rinkeby: {
      url: "https://late-sparkling-emerald.rinkeby.quiknode.pro/7e9a2258908e96261354cc97cbc10e5b5fa1a48c/",
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
