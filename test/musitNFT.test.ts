import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, } from "ethers";
import { Marketplace, MusitNFT } from "../typechain";

const ethToWei = (eth: number | string) =>
  ethers.utils.parseEther(eth.toString());
const weiToEth = (wei: BigNumber) => ethers.utils.formatEther(wei);

describe("Marketplace Contract", function () {
  let deployer: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let musitNFT: MusitNFT;
  let marketplace: Marketplace;
  let mintPrice: BigNumber;

  let feePercent: number = 1;
  let price: number = 2;
  let URI: string = "Token URI";

  this.beforeEach(async () => {
    // Signer 정보들 받아오기
    [deployer, addr1, addr2] = await ethers.getSigners();
    mintPrice = ethToWei(0.0001)
    // 컨트랙트 배포
    const MusitNFT = await ethers.getContractFactory("MusitNFT");
    const Marketplace = await ethers.getContractFactory("Marketplace");
    musitNFT = await MusitNFT.deploy(mintPrice);
    marketplace = await Marketplace.deploy(feePercent);
  });

  describe("Deployment", async () => {
    it("Should track name and symbol of MusitNFT contract", async () => {
      expect(await musitNFT.name()).to.equal("Musit NFT");
      expect(await musitNFT.symbol()).to.equal("MUSIT");
    })
  })

  describe("Minting NFT", async () => {
    it("Should track each minted NFT", async () => {
      await expect(
        await musitNFT.connect(addr1).minting(URI, { value: mintPrice })
      )
        .emit(musitNFT, "Minted")
        .withArgs(1, URI, addr1.address);

      expect(await musitNFT.balanceOf(addr1.address)).to.equal(1)
      expect(await musitNFT.ownerOf(1)).to.equal(addr1.address)
      expect(await musitNFT.tokenURI(1)).to.equal(URI)
    })
  })
});
