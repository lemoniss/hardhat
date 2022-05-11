// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MusitNFT.sol";

contract Auction is ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;
  MusitNFT musitNft;

  Counters.Counter public itemCounter;
  address payable public immutable feeAccount;
  uint public immutable feePercent;
  uint public minBidUnit;

  mapping (uint => Item) public items; // itemId => 경매아이템 : 경매에 올린 아이템 리스트
  mapping (address => mapping(uint => uint)) public nftToItemId; // [nft contract address] [tokenId]  => itemId (last enrolled)
  mapping (uint => mapping (address => uint)) public pendingBids; // itemId => ( bidder => bid ) : 입찰하려고 올린 금액들

  enum StatusType { ENROLLED, CLOSED, CANCELLED }

  struct Item {
    uint itemId;
    uint startPrice;
    uint startAt;
    uint endAt;
    uint tokenId;
    address payable seller;
    address topBidder;
    uint topBid;
    StatusType status;
    IERC721 nft;
  }

  /* Event declaration */
  event Enrolled(
    uint indexed itemId,
    uint _startPrice,
    address _nft, 
    uint indexed _tokenId, 
    address indexed seller
  );

  event Bid (uint indexed itemId, address indexed topBidder, uint topBid);
  event End(uint indexed itemId, address indexed buyer, address indexed seller, uint price, uint fee);
  event Cancel(uint indexed itemId, address indexed seller);
  event Withdraw (uint indexed itemId, address indexed bidder, uint balance);

/* Constructor */
  constructor(uint _feePercent) {
    feePercent = _feePercent; // 수수료 
    feeAccount = payable(msg.sender); // 수수료를 받을 지갑 주소
    minBidUnit = 0.00001 ether;
  }

  /* Modifier declaration */
  modifier onlyNftOwner (IERC721 _nft, uint _tokenId) {
    require(msg.sender == _nft.ownerOf(_tokenId), "Only owner can enroll nft");
    _;
  }
  modifier onlySellerTopBidder (uint _itemId) {
    require(msg.sender == items[_itemId].seller || msg.sender == items[_itemId].topBidder, 
            "Only seller or top bidder can end it.");
    _;
  }

  /* Function declaration */
  // 경매 아이템 등록 및 경매 시작 함수
  function enroll(uint _startPrice, uint _endAt, IERC721 _nft, uint _tokenId ) 
    external nonReentrant onlyNftOwner(_nft, _tokenId) {
    require(_startPrice % minBidUnit == 0, "Check the minimum unit of start price");
    require(_startPrice >= minBidUnit, "Should start price is bigger than mininum bid amount");
    require(block.timestamp < _endAt, "Cannot set end time as past time");
    musitNft = MusitNFT(address(_nft));
    require(!musitNft.getIsOnMarket(_tokenId), "This is on the market");

    itemCounter.increment();
    uint itemId = itemCounter.current();
    items[itemId] = Item(
      itemId,
      _startPrice, 
      block.timestamp,
      _endAt/1000, 
      _tokenId,
      payable(msg.sender),
      address(0),
      _startPrice,
      StatusType.ENROLLED,
      _nft
    );

    nftToItemId[address(_nft)][_tokenId] = itemId;

    _nft.transferFrom(msg.sender, address(this), _tokenId);

    emit Enrolled(itemId, _startPrice, address(_nft), _tokenId, msg.sender);
    musitNft.setIsOnMarket(_tokenId, true);
  }  

  // 경매 참여 함수
  function bid(uint _itemId) external payable nonReentrant {
    require(removeFee(msg.value) % minBidUnit == 0, "Check the minimum unit of bid");
    require(_itemId <= itemCounter.current(), "This item is not enrolled");
    Item storage auctionItem = items[_itemId];
    require(block.timestamp < auctionItem.endAt, "Auction is ended");
    require(auctionItem.status == StatusType.ENROLLED, "This auction is ended or cancelled");
    require(removeFee(msg.value) + pendingBids[_itemId][msg.sender] >= auctionItem.topBid + minBidUnit,
      "Bid amount should be bigger than prev top bid as much as minumum bid amount");

    pendingBids[_itemId][msg.sender] += removeFee(msg.value);
    auctionItem.topBid = pendingBids[_itemId][msg.sender];
    auctionItem.topBidder = msg.sender;

    emit Bid(_itemId, msg.sender, auctionItem.topBid);
  }

  // 경매 종료 함수
  function end(uint _itemId) external nonReentrant onlySellerTopBidder(_itemId) {
    Item storage auctionItem = items[_itemId];
    require(auctionItem.status == StatusType.ENROLLED, "This item hasn't been enrolled");
    require(block.timestamp > auctionItem.endAt, "It is not the time to close auction");
    auctionItem.status = StatusType.CLOSED;
    uint fee = (auctionItem.topBid * feePercent) / 100;

    if (auctionItem.topBidder != address(0)) {
      auctionItem.nft.transferFrom(address(this), auctionItem.topBidder, auctionItem.tokenId);
      auctionItem.seller.transfer(auctionItem.topBid); // 수수료 제외한 나머지 판매자에게 전송
      feeAccount.transfer(fee); // 수수료는 배포자에게 전송
      pendingBids[_itemId][auctionItem.topBidder] = 0;  // 입찰자는 출금을 못하도록 0으로 바꿈
    } else {
      auctionItem.nft.transferFrom(address(this), auctionItem.seller, auctionItem.tokenId);
    }
    
    nftToItemId[address(auctionItem.nft)][auctionItem.tokenId] = 0;

    emit End(_itemId, auctionItem.topBidder, auctionItem.seller, auctionItem.topBid, fee);

    musitNft = MusitNFT(address(auctionItem.nft));
    musitNft.setIsOnMarket(auctionItem.tokenId, false);
  }

  // 경매 강제 종료 함수
  function forceEnd(uint _itemId)  external nonReentrant onlyOwner {
    Item storage auctionItem = items[_itemId];
    require(auctionItem.status == StatusType.ENROLLED, "This item hasn't been enrolled");
    auctionItem.status = StatusType.CLOSED;
    uint fee = (auctionItem.topBid * feePercent) / 100;

    if (auctionItem.topBidder != address(0)) {
      auctionItem.nft.safeTransferFrom(address(this), auctionItem.topBidder, auctionItem.tokenId);
      auctionItem.seller.transfer(auctionItem.topBid); // 수수료 제외한 나머지 판매자에게 전송
      feeAccount.transfer((auctionItem.topBid * feePercent) / 100); // 수수료는 배포자에게 전송
      pendingBids[_itemId][auctionItem.topBidder] = 0;  // 입찰자는 출금을 못하도록 0으로 바꿈
    } else {
      auctionItem.nft.safeTransferFrom(address(this), auctionItem.seller, auctionItem.tokenId);
    }

    nftToItemId[address(auctionItem.nft)][auctionItem.tokenId] = 0;
    
    emit End(_itemId, auctionItem.topBidder,  auctionItem.seller, auctionItem.topBid, fee);
    musitNft = MusitNFT(address(auctionItem.nft));
    musitNft.setIsOnMarket(auctionItem.tokenId, false);
  }

  // 경매 입찰 참여자가 없으면 경매 취소할 수 있는 함수
  function cancel(uint _itemId) external nonReentrant {
    Item storage auctionItem = items[_itemId];
    require(msg.sender == auctionItem.seller, "Only seller can cancel it");
    require(auctionItem.status == StatusType.ENROLLED , "It is already started or ended");
    require(auctionItem.topBidder == address(0), "Cannot cancel the item that is bidden");
    auctionItem.status = StatusType.CANCELLED;

    auctionItem.nft.transferFrom(address(this), auctionItem.seller, auctionItem.tokenId);
    nftToItemId[address(auctionItem.nft)][auctionItem.tokenId] = 0;

    emit Cancel(_itemId, msg.sender);
    musitNft = MusitNFT(address(auctionItem.nft));
    musitNft.setIsOnMarket(auctionItem.tokenId, false);
  }

  // 강제 취소 함수
  function forceCancel(uint _itemId) external nonReentrant onlyOwner {
    Item storage auctionItem = items[_itemId];
    require(auctionItem.status == StatusType.ENROLLED , "It is already started or ended");
    auctionItem.status = StatusType.CANCELLED;

    payable(auctionItem.topBidder).transfer(auctionItem.topBid);
    auctionItem.nft.transferFrom(address(this), auctionItem.seller, auctionItem.tokenId);
    nftToItemId[address(auctionItem.nft)][auctionItem.tokenId] = 0;

    emit Cancel(_itemId, msg.sender);
    musitNft = MusitNFT(address(auctionItem.nft));
    musitNft.setIsOnMarket(auctionItem.tokenId, false);
  }

  // pending bids 출금 함수
  function withdraw(uint _itemId) external nonReentrant {
    uint balance = pendingBids[_itemId][msg.sender];
    require(balance != 0, "Nothing to withdraw");
    require(msg.sender != items[_itemId].topBidder, "Top bidder cannot withdraw");
    pendingBids[_itemId][msg.sender] = 0;

    payable(msg.sender).transfer(calPriceWithFee(balance));

    emit Withdraw(_itemId, msg.sender, balance);
  }
  
  function calPriceWithFee(uint _price) public view returns(uint) {
    return (_price * (100 + feePercent))/ 100;
  }

  function removeFee(uint _priceWithFee) public view returns (uint) {
    return (_priceWithFee * 100) / (100 + feePercent);
  }

  function getBlockTimestamp() public view returns (uint) {
    return block.timestamp;
  }
  
  function getPendingBids(uint _itemId, address _addr) public view returns (uint) {
    return pendingBids[_itemId][_addr];
  }

  function getNftToItemId(address _nft, uint256 _tokenId) public view returns (uint256) {
    return nftToItemId[_nft][_tokenId];
  }
}