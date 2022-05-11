// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



contract MusitNFT is ERC721URIStorage, ERC721Enumerable, Ownable {
  using Counters for Counters.Counter;

  mapping (uint => bool) isOnMarket; // tokenId => enrolled on market

  uint256 public mintPrice; // 민팅 가격
  uint256 public totalSupplied; // 현재까지 발행된 총 수량
  Counters.Counter public tokenCount; // 발행할 NFT 토큰 Id

  event Minted (uint256 tokenId, string tokenURI, address indexed minter);

  constructor (uint _mintPrice) ERC721("Musit NFT","MUSIT") {
    mintPrice = _mintPrice;
  }

  /* override functions related to ERC721*/
  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  function setMintPrice (uint256 _mintPrice) external onlyOwner {
    mintPrice = _mintPrice;
  }

  /* Minting 함수 */
  function minting (string memory _tokenURI) external payable returns (uint256) {
    require(msg.value == mintPrice, "Wrong value sent.");
    
    tokenCount.increment();
    uint256 newTokenId = tokenCount.current();
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, _tokenURI);
    emit Minted(newTokenId, _tokenURI, msg.sender);
    totalSupplied = newTokenId;

    return newTokenId;
  }

  function getIsOnMarket(uint _tokenId) external view returns(bool) {
    return isOnMarket[_tokenId];
  }
  function setIsOnMarket(uint _tokenId, bool _isOnMarket) external {
    isOnMarket[_tokenId]  = _isOnMarket;
  }
}