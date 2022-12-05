import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, } from "ethers";
import { Marketplace, MillimxNft } from "../typechain";

const ethToWei = (eth: number | string) =>
  ethers.utils.parseEther(eth.toString());
const weiToEth = (wei: BigNumber) => ethers.utils.formatEther(wei);

describe("Millim-X Contract", function () {
  let deployer: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let millimxNft: MillimxNft;
  let marketplace: Marketplace;
  let mintPrice: BigNumber;

  let feePercent: number = 2;
  let price: number = 2;
  let URI: string = "QmR3vXP4dnSenQyE7DxANmPKajNb4B7CupbNWd6DgZpsvc";

  let itemId: number = 5;

  this.beforeEach(async () => {
    // Signer 정보들 받아오기
    [deployer, addr1, addr2] = await ethers.getSigners();
    mintPrice = ethToWei(0.005)
    // 컨트랙트 배포
    // const MillimxNft = await ethers.getContractFactory("MillimxNft");
    const Marketplace = await ethers.getContractFactory("Marketplace");
    // millimxNft = await MillimxNft.deploy(ethers.utils.parseEther("0.005"), 50000, ethers.utils.parseEther("0.009"));
    marketplace = await Marketplace.deploy(50000, 75000);
  });

  // describe("Deployment", async () => {
  //   it("Should track name and symbol of MillimxNft contract", async () => {
  //     expect(await millimxNft.name()).to.equal("Millimx Nft");
  //     expect(await millimxNft.symbol()).to.equal("MLX");
  //   })
  // })

  // describe("Minting NFT", async () => {
  //   it("Should track each minted NFT", async () => {
  //     await expect(
  //       await millimxNft.connect("0x913C770f77F0aaae8BA94F29492a6784D16e1DA1").minting(URI, { value: mintPrice })
  //     )
  //       .emit(millimxNft, "Minted")
  //       .withArgs(1, URI, "0x913C770f77F0aaae8BA94F29492a6784D16e1DA1");
  //
  //     expect(await millimxNft.balanceOf("0x913C770f77F0aaae8BA94F29492a6784D16e1DA1")).to.equal(1)
  //     // expect(await millimxNft.ownerOf(1)).to.equal(addr1.address)
  //     // expect(await millimxNft.tokenURI(1)).to.equal(URI)
  //   })
  // })

  describe("Market Purchase", async () => {
    it("market purchase NFT", async () => {
      expect(
          await marketplace.connect("0x913C770f77F0aaae8BA94F29492a6784D16e1DA1").purchase(itemId, {value: 5})
      );
          // .emit(millimxNft, "Minted")
          // .withArgs(1, URI, "0x913C770f77F0aaae8BA94F29492a6784D16e1DA1");

      // expect(await millimxNft.balanceOf("0x913C770f77F0aaae8BA94F29492a6784D16e1DA1")).to.equal(1)
      // expect(await millimxNft.ownerOf(1)).to.equal(addr1.address)
      // expect(await millimxNft.tokenURI(1)).to.equal(URI)
    })
  })
});
