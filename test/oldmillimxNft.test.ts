// import {BigNumber} from "ethers";
//
// const { expect } = require("chai");
// const { ethers } = require("hardhat");
//
// const ethToWei = (eth: number | string) =>
//   ethers.utils.parseEther(eth.toString());
// const weiToEth = (wei: BigNumber) => ethers.utils.formatEther(wei);
//
// describe("MillimxNft", function () {
//     it("Should return the new greeting once it's changed", async function () {
//         const millimxNftFactory = await ethers.getContractFactory("MillimxNft");
//         const millimxContract = await millimxNftFactory.deploy(ethToWei(0.005));
//         await millimxContract.deployed();
//
//         console.log(millimxContract.mintPrice);
//
//         await millimxContract.setMintPrice(ethToWei(0.005));
//
//         console.log(millimxContract.mintPrice);
//     });
//
// //   describe("Minting NFT", async () => {
// //     it("Should track each minted NFT", async () => {
// //       await expect(
// //         await millimxNft.connect(addr1).minting(URI, { value: mintPrice })
// //       )
// //         .emit(millimxNft, "Minted")
// //         .withArgs(1, URI, addr1.address);
// //
// //       expect(await millimxNft.balanceOf(addr1.address)).to.equal(1)
// //       expect(await millimxNft.ownerOf(1)).to.equal(addr1.address)
// //       expect(await millimxNft.tokenURI(1)).to.equal(URI)
// //     })
// //   })
// });
