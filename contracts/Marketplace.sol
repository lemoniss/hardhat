// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MusitNFT.sol";

contract Marketplace is ReentrancyGuard {
  using Counters for Counters.Counter;
  MusitNFT musitNft;

  address payable public immutable feeAccount; // 수수료를 받을 주소
  uint256 public immutable feePercent; // 팔때 받을 수수료
  Counters.Counter public itemCount;

  mapping (uint256 => Item) public items; // itemId => Item
  mapping (address => mapping(uint => uint)) public nftToItemId; // [nft contract address] [tokenId]  => itemId (last enrolled)
  
  struct Item {
    uint256 itemId; // 판매 등록한 아이템 id
    uint256 tokenId;  // 판매할 토큰 id
    uint256 price;
    address payable seller;
    IERC721 nft;
    bool sold;
  }
  
  event Enrolled (
    uint256 itemId,
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed nft
  );

  event Bought (
    uint256 itemId,
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed buyer,
    address indexed nft
  );

  constructor (uint256 _feePercent) {
    feeAccount = payable(msg.sender);
    feePercent = _feePercent;
  }

  function enroll(IERC721 _nft, uint256 _tokenId, uint256 _price) external nonReentrant {
    require(_price > 0, "Price must be greater than zero");
    require(msg.sender == _nft.ownerOf(_tokenId), "Only owner can enroll");
    musitNft = MusitNFT(address(_nft));
    require(!musitNft.getIsOnMarket(_tokenId), "This is on the market");

    itemCount.increment();
    uint256 itemId = itemCount.current();
    _nft.transferFrom(msg.sender, address(this), _tokenId);

    items[itemId] = Item (
      itemId,
      _tokenId,
      _price,
      payable(msg.sender),
      _nft,
      false
    );

    emit Enrolled (
      itemId,
      _tokenId,
      _price,
      msg.sender,
      address(_nft)
    );
    
    nftToItemId[address(_nft)][_tokenId] = itemId;
    musitNft.setIsOnMarket(_tokenId, true);
  }

  function purchase(uint256 _itemId) external payable nonReentrant {
    uint256 _totalPrice = getTotalPrice(_itemId);
    Item storage item = items[_itemId];
    require(_itemId > 0 && _itemId <= itemCount.current(), "Item doesn't exist");
    require(msg.value >= _totalPrice , "Not enough ether to cover item price and market fee");
    require(!item.sold, "Sold out!");

    // pay seller and fee account
    item.seller.transfer(item.price);
    feeAccount.transfer(_totalPrice - item.price);

    // update item to sold
    item.sold = true;

    // transfer nft to buyer
    item.nft.safeTransferFrom(address(this), msg.sender, item.tokenId);

    nftToItemId[address(item.nft)][item.tokenId] = 0;

    // emit Bought event
    emit Bought(
      _itemId, 
      item.tokenId, 
      item.price, 
      item.seller, 
      msg.sender, 
      address(item.nft)
    );

    musitNft = MusitNFT(address(item.nft));
    musitNft.setIsOnMarket(item.tokenId, false);
  }

  function getTotalPrice(uint256 _itemId) public view returns (uint256) {
    return (items[_itemId].price * (100 + feePercent)) /100;
  }

  function getNftToItemId(address _nft, uint256 _tokenId) public view returns (uint256) {
    return nftToItemId[_nft][_tokenId];
  }
}