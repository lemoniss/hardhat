import { Contract } from "ethers";
import fs from "fs";
import { artifacts, ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);

  // We get the contract to deploy
  console.log("Deploying MusitNFT");
  const MusitNFT = await ethers.getContractFactory("MusitNFT");
  const musitNFT = await (await MusitNFT.deploy(ethers.utils.parseEther("0.0001"))).deployed();
  console.log("MusitNFT address:", musitNFT.address);
  
  console.log("Deploying Marketplace");
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await (await Marketplace.deploy(1)).deployed();
  console.log("Marketplace address:", marketplace.address);
  
  console.log("Deploying Auction");
  const Auction = await ethers.getContractFactory("Auction");
  const auction = await (await Auction.deploy(1)).deployed();
  console.log("Auction address:", auction.address);

  console.log("Deploying Subscription");
  const Subscription = await ethers.getContractFactory("Subscription");
  const subscription = await (await Subscription.deploy()).deployed();
  console.log("Subscription address:", subscription.address);


  saveJsonFilesToClientFolder(musitNFT, "MusitNFT");
  saveJsonFilesToClientFolder(marketplace, "Marketplace");
  saveJsonFilesToClientFolder(auction, "Auction");
  saveJsonFilesToClientFolder(subscription, "Subscription");
}

function saveJsonFilesToClientFolder(contract: Contract, name: string) {
  const contractsDir = __dirname + "/../../client/src/web3/";

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
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
