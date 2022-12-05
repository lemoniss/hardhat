import { Contract } from "ethers";
import fs from "fs";
import { artifacts, ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);

  // We get the contract to deploy
  console.log("Deploying MillimxNft");
  // 20000 = 2%, 25000 = 2.5%, 50000 = 5%,
  // 민팅수수료 : 0.005ETH , 거래수수료 : 5% , 선물배송비 : 0.009ETH
  const MillimxNft = await ethers.getContractFactory("MillimxNft");
  const millimxNft = await (await MillimxNft.deploy(ethers.utils.parseEther("0.005"), 50000, ethers.utils.parseEther("0.009"))).deployed();
  console.log("MillimxNft address:", millimxNft.address);

  // console.log("Deploying Showtime");
  // // 20000 = 2%, 25000 = 2.5%
  // const Showtime = await ethers.getContractFactory("Showtime");
  // const showtime = await (await Showtime.deploy(25000)).deployed();
  // console.log("Showtime address:", showtime.address);

  console.log("Deploying Marketplace");
  // 20000 = 2%, 25000 = 2.5%, 50000 = 5%, 75000 = 7.5%
  // 거래수수료 : 5% , 로열티 : 7.5%
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await (await Marketplace.deploy(50000, 75000)).deployed();
  console.log("Marketplace address:", marketplace.address);

  // console.log("Deploying Auction");
  // const Auction = await ethers.getContractFactory("Auction");
  // const auction = await (await Auction.deploy(1)).deployed();
  // console.log("Auction address:", auction.address);

  // console.log("Deploying Subscription");
  // const Subscription = await ethers.getContractFactory("Subscription");
  // const subscription = await (await Subscription.deploy()).deployed();
  // console.log("Subscription address:", subscription.address);


  saveJsonFilesToClientFolder(millimxNft, "MillimxNft");
  // saveJsonFilesToClientFolder(showtime, "Showtime");
  saveJsonFilesToClientFolder(marketplace, "Marketplace");
  // saveJsonFilesToClientFolder(auction, "Auction");
  // saveJsonFilesToClientFolder(subscription, "Subscription");
}

function saveJsonFilesToClientFolder(contract: Contract, name: string) {
  const contractsDir = __dirname + "/../client/src/web3/";

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }

  const contractArtifact = artifacts.readArtifactSync(name);

  fs.writeFileSync(
    contractsDir + `/${name}.json`,
    JSON.stringify(
      { contractAddress: contract.address, ...contractArtifact },
      undefined,
      4
    )
  );
}

main()
  .then(() => {
    process.exitCode = 0;
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
