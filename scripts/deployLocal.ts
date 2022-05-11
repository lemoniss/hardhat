import hre, { ethers } from "hardhat";

async function main() {
  hre.run("compile");

  const [deployer, addr1, addr2, addr3] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);

  // We get the contract to deploy
  const MusitNFT = await ethers.getContractFactory("MusitNFT");
  const musitNFT = await (await MusitNFT.deploy(hre.ethers.utils.parseEther("0.0001"))).deployed();


  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await (await Marketplace.deploy(1)).deployed();

  const Auction = await ethers.getContractFactory("Auction");
  const auction = await (await Auction.deploy(1)).deployed();

  console.log("MusitNFT address:", musitNFT.address);
  console.log("Marketplace address:", marketplace.address);
  console.log("Auction address:", auction.address);

}

main()
  .then(() => {
    process.exitCode = 0;
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
