// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MillimxNft is ERC721URIStorage, ERC721Enumerable, Ownable, ReentrancyGuard {
  using Counters for Counters.Counter;

  // 민팅 수수료 지갑 어떤걸로?
  address payable public mintFeeAccount;
  uint256 public mintFee;

  // 쇼타임 구매수수료 지갑
  address payable public smPurchaseFeeAccount;
  uint256 public smPurchaseFeePercent;

  // 선물하기 배송비 지갑
  address payable public giftFeeAccount;
  uint256 public giftFee;

  // 쇼타임민팅용 지갑
  address payable public smMintAccount;

  modifier onlyShowtimeMinter() {
    require(smMintAccount == msg.sender, "caller is not the ShowtimeMinter");
    _;
  }

  mapping (uint => bool) isOnMarket;
  mapping (uint256 => ShowTimeItem) public showTimeItems;

  mapping (uint256 => address[]) public splitAddress;
  mapping (uint256 => uint256[]) public splitPercent;

  uint256 public totalSupplied;
  Counters.Counter public tokenCount;

  struct ShowTimeItem {
    uint256 tokenId;
    uint256 price;
    address payable seller;
    bool sold;
  }

  event Minted (
    uint256 tokenId,
    string tokenURI,
    address indexed minter
  );

  event ShowTimeMinted (
    uint256 tokenId,
    string tokenURI,
    uint256 price,
    address indexed minter
  );

  event ShowTimeBought (
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed buyer
  );

  event NftGift(
    uint256 tokenId,
    address indexed fromAddress,
    address indexed toAddress
  );

  event MintFee(
    uint256 tokenId,
    address indexed millimxAddress,
    uint256 feePercent,
    uint256 feePrice
  );

  event ShowTimeBoughtFee(
    uint256 tokenId,
    address indexed millimxAddress,
    uint256 feePercent,
    uint256 feePrice
  );

  event GiftFee(
    uint256 tokenId,
    address indexed millimxAddress,
    uint256 feePercent,
    uint256 feePrice
  );

  event ShowTimeRoyalty(
    uint256 tokenId,
    address indexed royaltyAddress,
    uint256 royaltyPercent,
    uint256 royaltyPrice
  );

  constructor (uint _mintFee, uint _feePercent, uint _nftGiftFee) ERC721("Millim:X","MLX") {
    mintFeeAccount = payable(0x2B8b712479e39BB2aA3C927a3A5b016036Eecc7E);
    mintFee = _mintFee;

    smPurchaseFeeAccount = payable(0xdca8329006F93E2905663010cAE895109db0b14c);
    smPurchaseFeePercent = _feePercent;

    giftFeeAccount = payable(0x341DEd1deb57863b22af117D0d7EAec400969e5a);
    giftFee = _nftGiftFee;

    smMintAccount = payable(0x4d6B9F1fA7ED84E2A78d218B2b7f0FA46ecCf3ea);
  }

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

  function setMintFeeAccount (address _mintFeeAccount) external onlyOwner {
    require(_mintFeeAccount != address(0), "MintFeeAccount is the zero address");
    mintFeeAccount = payable(_mintFeeAccount);
  }

  function setMintFee (uint256 _mintFee) external onlyOwner {
    mintFee = _mintFee;
  }

  function setSmPurchaseFeeAccount (address _smPurchaseFeeAccount) external onlyOwner {
    require(_smPurchaseFeeAccount != address(0), "SmPurchaseFeeAccount is the zero address");
    smPurchaseFeeAccount = payable(_smPurchaseFeeAccount);
  }

  function setSmPurchaseFeePercent (uint256 _smPurchaseFeePercent) external onlyOwner {
    smPurchaseFeePercent = _smPurchaseFeePercent;
  }

  function setGiftFeeAccount (address _giftFeeAccount) external onlyOwner {
    require(_giftFeeAccount != address(0), "GiftFeeAccount is the zero address");
    giftFeeAccount = payable(_giftFeeAccount);
  }

  function setGiftFee (uint256 _giftFee) external onlyOwner {
    giftFee = _giftFee;
  }

  function setSmMintAccount (address _smMintAccount) external onlyOwner {
    require(_smMintAccount != address(0), "GiftFeeAccount is the zero address");
    smMintAccount = payable(_smMintAccount);
  }


  function minting (string memory _tokenURI, address[] memory _splitAddress, uint256[] memory _splitPercent) external payable returns (uint256) {
    require(msg.value == mintFee, "Wrong value sent.");

    tokenCount.increment();
    uint256 newTokenId = tokenCount.current();
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, _tokenURI);
    emit Minted(newTokenId, _tokenURI, msg.sender);
    totalSupplied = newTokenId;

    mintFeeAccount.transfer(msg.value);
    emit MintFee(
      newTokenId,
      mintFeeAccount,
      mintFee,
      msg.value
    );

    for(uint j=0; j< _splitAddress.length; j++) {
      splitAddress[newTokenId].push(_splitAddress[j]);
      splitPercent[newTokenId].push(_splitPercent[j]);
    }

    return newTokenId;
  }

  function showTimeMinting (string[] memory _tokenURIs, uint256[] memory _sellPrices, address[] memory _splitAddress, uint256[] memory _splitPercent) external onlyShowtimeMinter payable  {
    for(uint i=0; i< _tokenURIs.length; i++) {
      tokenCount.increment();
      uint256 newTokenId = tokenCount.current();
      _safeMint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, _tokenURIs[i]);
      totalSupplied = newTokenId;

      showTimeItems[newTokenId] = ShowTimeItem (
        newTokenId,
        _sellPrices[i] * (10**15),
        payable(msg.sender),
        false
      );

      emit ShowTimeMinted(
        newTokenId,
        _tokenURIs[i],
        _sellPrices[i] * (10**15),
        msg.sender
      );

      transferFrom(msg.sender, address(this), newTokenId);

      for(uint j=0; j< _splitAddress.length; j++) {
        splitAddress[newTokenId].push(_splitAddress[j]);
        splitPercent[newTokenId].push(_splitPercent[j]);
      }
    }
  }

  function showTimePurchase(uint256 _tokenId) external payable nonReentrant {
    uint256 _price = showTimeItems[_tokenId].price;
    ShowTimeItem storage showTimeItem = showTimeItems[_tokenId];
    require(_tokenId > 0 && _tokenId <= tokenCount.current(), "Item doesn't exist");
    require(msg.value >= _price , "Not enough ether to cover item price and market fee");
    require(!showTimeItem.sold, "Sold out!");

    smPurchaseFeeAccount.transfer(calculateFee(_price, smPurchaseFeePercent));
    emit ShowTimeBoughtFee(
      _tokenId,
      smPurchaseFeeAccount,
      smPurchaseFeePercent,
      calculateFee(_price, smPurchaseFeePercent)
    );

    _price = _price - calculateFee(_price, smPurchaseFeePercent);

    for(uint i=0; i< splitAddress[_tokenId].length; i++) {
      payable(splitAddress[_tokenId][i]).transfer(calculateFee(_price, splitPercent[_tokenId][i]));
      emit ShowTimeRoyalty(
        _tokenId,
        splitAddress[_tokenId][i],
        splitPercent[_tokenId][i],
        calculateFee(_price, splitPercent[_tokenId][i])
      );
    }

    showTimeItem.sold = true;

    _transfer(address(this), msg.sender, _tokenId);

    emit ShowTimeBought(
      _tokenId,
      showTimeItem.price,
      showTimeItem.seller,
      msg.sender
    );
  }

  function showTimeFreeMinting (string memory _tokenURI, address[] memory _toAddress, address[] memory _splitAddress, uint256[] memory _splitPercent) external onlyOwner payable  {
    for(uint i=0; i< _toAddress.length; i++) {
      tokenCount.increment();
      uint256 newTokenId = tokenCount.current();
      _safeMint(msg.sender, newTokenId);
      _setTokenURI(newTokenId, _tokenURI);
      totalSupplied = newTokenId;

      showTimeItems[newTokenId] = ShowTimeItem(
        newTokenId,
        0,
        payable(msg.sender),
        false
      );

      emit ShowTimeMinted(
        newTokenId,
        _tokenURI,
        0,
        msg.sender
      );

      _transfer(msg.sender, _toAddress[i], newTokenId);

      for(uint j=0; j< _splitAddress.length; j++) {
        splitAddress[newTokenId].push(_splitAddress[j]);
        splitPercent[newTokenId].push(_splitPercent[j]);
      }
    }
  }

  function nftGift(uint256 _tokenId, address toAddress) external payable nonReentrant {
    require(msg.sender == ownerOf(_tokenId), "Only owner can enroll");
    require(!isOnMarket[_tokenId], "This is on the market");

    if(giftFee > 0) {
      require(msg.value >= giftFee , "Not enough ether to NFT give a gift fee price");
      giftFeeAccount.transfer(msg.value);
      emit GiftFee(
        _tokenId,
        giftFeeAccount,
        giftFee,
        msg.value
      );
    }

    _transfer(msg.sender, toAddress, _tokenId);

    emit NftGift(
      _tokenId,
      msg.sender,
      toAddress
    );
  }

  function getIsOnMarket(uint _tokenId) external view returns(bool) {
    return isOnMarket[_tokenId];
  }
  function setIsOnMarket(uint _tokenId, bool _isOnMarket) external {
    isOnMarket[_tokenId]  = _isOnMarket;
  }

  function getMyNftItems(uint256 _balanceIndex) external view returns (string memory, uint256) {
    uint256 tokenId = tokenOfOwnerByIndex(msg.sender, _balanceIndex);
    string memory tokenUri = tokenURI(tokenId);
    return (tokenUri, tokenId);
  }

  function getMyNftItemDetail(uint256 _tokenId) external view returns (string memory) {
    string memory tokenUri = tokenURI(_tokenId);
    return (tokenUri);
  }

  function calculateFee(uint256 _price, uint256 _percent) internal pure returns (uint256) {
    require((_price / 1000000) * 1000000 == _price, 'too small');
    return (_price * (_percent)) / 1000000;
  }

  function getSplitAddress(uint _tokenId) external view returns(address[] memory) {
    return splitAddress[_tokenId];
  }

  function getSplitPercent(uint _tokenId) external view returns(uint256[] memory) {
    return splitPercent[_tokenId];
  }

  function withdraw() external payable onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }
}
