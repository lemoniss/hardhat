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

  address payable public immutable feeAccount; // 수수료를 받을 주소
  uint256 public feePercent; // 팔때 받을 수수료

  mapping (uint => bool) isOnMarket; // tokenId => enrolled on market
  mapping (uint256 => ShowTimeItem) public showTimeItems;

  mapping (uint256 => address[]) public splitAddress;
  mapping (uint256 => uint256[]) public splitPercent;

  uint256 public mintPrice; // 민팅 가격
  uint256 public totalSupplied; // 현재까지 발행된 총 수량
  Counters.Counter public tokenCount; // 발행할 NFT 토큰 Id
  uint256 public normalNftTransferFeePrice; // 일반NFT전송시 전송수수료(배송비)

  struct ShowTimeItem {
    uint256 tokenId;  // 판매할 토큰 id
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

  event ShowTimeNftTransfer(
    uint256 tokenId,
    address indexed toAddress
  );

  event NormalNftTransfer(
    uint256 tokenId,
    address indexed fromAddress,
    address indexed toAddress
  );

  constructor (uint _mintPrice, uint _feePercent) ERC721("Millim:X","MLX") {
    mintPrice = _mintPrice;
    feePercent = _feePercent;
    feeAccount = payable(msg.sender);
    normalNftTransferFeePrice = 0;
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

  function setFeePercent (uint256 _feePercent) external onlyOwner {
    feePercent = _feePercent;
  }

  function setNormalNftTransferFeePrice (uint256 _normalNftTransferFeePrice) external onlyOwner {
    normalNftTransferFeePrice = _normalNftTransferFeePrice;
  }


  /* 일반 Minting */
  function minting (string memory _tokenURI, address[] memory _splitAddress, uint256[] memory _splitPercent) external payable returns (uint256) {
    require(msg.value == mintPrice, "Wrong value sent.");

    tokenCount.increment();
    uint256 newTokenId = tokenCount.current();
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, _tokenURI);
    emit Minted(newTokenId, _tokenURI, msg.sender);
    totalSupplied = newTokenId;

    for(uint j=0; j< _splitAddress.length; j++) {
      splitAddress[newTokenId].push(_splitAddress[j]);
      splitPercent[newTokenId].push(_splitPercent[j]);
    }

    return newTokenId;
  }

  /** Showtime Minting */
  function showTimeMinting (string[] memory _tokenURIs, uint256[] memory _sellPrices, address[] memory _splitAddress, uint256[] memory _splitPercent) external onlyOwner payable  {
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

      // 민팅한 토큰을 스마트컨트랙트로 전송
      transferFrom(msg.sender, address(this), newTokenId);

      for(uint j=0; j< _splitAddress.length; j++) {
        splitAddress[newTokenId].push(_splitAddress[j]);
        splitPercent[newTokenId].push(_splitPercent[j]);
      }

    }
  }

  /** Showtime 구매 */
  function showTimePurchase(uint256 _tokenId) external payable nonReentrant {
    uint256 _price = showTimeItems[_tokenId].price;
    ShowTimeItem storage showTimeItem = showTimeItems[_tokenId];
    require(_tokenId > 0 && _tokenId <= tokenCount.current(), "Item doesn't exist");
    require(msg.value >= _price , "Not enough ether to cover item price and market fee");
    require(!showTimeItem.sold, "Sold out!");

    // 회사가 먹는 거래수수료
    feeAccount.transfer(calculateFee(_price, feePercent));

    _price = _price - calculateFee(_price, feePercent);

    // 수익분배자들한테 수익률대로 전달함
    for(uint i=0; i< splitAddress[_tokenId].length; i++) {
      payable(splitAddress[_tokenId][i]).transfer(calculateFee(_price, splitPercent[_tokenId][i]));
    }

    // update item to sold
    showTimeItem.sold = true;

    // transfer nft to buyer
    _transfer(address(this), msg.sender, _tokenId);

    // emit Bought event
    emit ShowTimeBought(
      _tokenId,
      showTimeItem.price,
      showTimeItem.seller,
      msg.sender
    );
  }

  /** Showtime NFT 선물하기 */
  function showTimeNftTransfer(uint256 _tokenId, address toAddress) external onlyOwner payable nonReentrant {
    ShowTimeItem storage showTimeItem = showTimeItems[_tokenId];
    // 내가 가지고 있는것만 선물하기 되야 함
    require(msg.sender == ownerOf(_tokenId), "Only owner can enroll");

    // transfer nft to buyer
    _transfer(address(this), toAddress, showTimeItem.tokenId);

    // emit ShowTimeNftTransfer event
    emit ShowTimeNftTransfer(
      _tokenId,
      toAddress
    );
  }

  /** 일반 NFT 선물하기 */
  function normalNftTransfer(uint256 _tokenId, address toAddress) external payable nonReentrant {
    ShowTimeItem storage showTimeItem = showTimeItems[_tokenId];
    // 내가 가지고 있는것만 선물하기 되야 함
    require(msg.sender == ownerOf(_tokenId), "Only owner can enroll");

    if(normalNftTransferFeePrice > 0) { // 배송비가 무료가 아니라면?
      // 배송비 체크
      require(msg.value == normalNftTransferFeePrice, "Wrong value normalNftTransferFeePrice.");
    }

    // transfer nft to buyer
    _transfer(address(this), toAddress, showTimeItem.tokenId);

    // emit ShowTimeNftTransfer event
    emit NormalNftTransfer(
      _tokenId,
      msg.sender,
      toAddress
    );
  }

  // 마켓 등록 여부 가져오기
  function getIsOnMarket(uint _tokenId) external view returns(bool) {
    return isOnMarket[_tokenId];
  }
  // 마켓 등록 여부 설정
  function setIsOnMarket(uint _tokenId, bool _isOnMarket) external {
    isOnMarket[_tokenId]  = _isOnMarket;
  }

  // 내 NFT 목록
  function getMyNftItems(uint256 _balanceIndex) external view returns (string memory, uint256) {
    uint256 tokenId = tokenOfOwnerByIndex(msg.sender, _balanceIndex);
    string memory tokenUri = tokenURI(tokenId);
    return (tokenUri, tokenId);
  }

  // 내 NFT TokenUri
  function getMyNftItemDetail(uint256 _tokenId) external view returns (string memory) {
    string memory tokenUri = tokenURI(_tokenId);
    return (tokenUri);
  }

  // 수수료 계산
  function calculateFee(uint256 _price, uint256 _percent) internal pure returns (uint256) {
    require((_price / 1000000) * 1000000 == _price, 'too small');
    return (_price * (_percent)) / 1000000;
  }

  // 로열티 받을 주소들
  function getSplitAddress(uint _tokenId) external view returns(address[] memory) {
    return splitAddress[_tokenId];
  }

  // 로열티 퍼센트들
  function getSplitPercent(uint _tokenId) external view returns(uint256[] memory) {
    return splitPercent[_tokenId];
  }

  // 출금
  function withdraw() external payable onlyOwner {
    // =============================================================================
    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    payable(msg.sender).transfer(address(this).balance);
    // =============================================================================
  }

}

// 회사 지갑주소
// 0x7072bE4997CEF6a6c2758479f6565Be45c3b5E50
// 회사 개인키
// 765e11be658a3afb69148f07c6a42298f78fde029c2dcafa01809d2503b6f294
