// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MillimxNft.sol";

contract Marketplace is ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;
  MillimxNft millimxNft;

  address payable public immutable feeAccount; // 수수료를 받을 주소
  uint256 public feePercent; // 팔때 받을 수수료
  Counters.Counter public itemCount;

  uint256 public royaltyPercent;  // 로열티 수수료 default 7.5%

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

  event Registered (
    uint256 itemId,
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed nft
  );

  event Cancel (
    uint256 itemId,
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed buyer,
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

  constructor (uint256 _feePercent, uint256 _royaltyPercent) {
    feeAccount = payable(msg.sender);
    feePercent = _feePercent;
    royaltyPercent = _royaltyPercent;
  }

  function register(IERC721 _nft, uint256 _tokenId, uint256 _price) external nonReentrant {
    require(_price > 0, "Price must be greater than zero");
    require(msg.sender == _nft.ownerOf(_tokenId), "Only owner can regist");
    millimxNft = MillimxNft(address(_nft));
    require(!millimxNft.getIsOnMarket(_tokenId), "This is on the market");
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
    emit Registered (
      itemId,
      _tokenId,
      _price,
      msg.sender,
      address(_nft)
    );

    nftToItemId[address(_nft)][_tokenId] = itemId;
    millimxNft.setIsOnMarket(_tokenId, true);

  }

  function cancel(uint256 _itemId) external payable nonReentrant {
    Item storage item = items[_itemId];
    require(_itemId > 0 && _itemId <= itemCount.current(), "Item doesn't exist");
    require(msg.sender == item.seller, "Only owner can cancel");
    require(!item.sold, "Sold out!");

    // update item to sold
    item.sold = true;

    // transfer nft to buyer
    item.nft.safeTransferFrom(address(this), msg.sender, item.tokenId);

    nftToItemId[address(item.nft)][item.tokenId] = 0;

    // emit Cancel event
    emit Cancel(
      _itemId,
      item.tokenId,
      item.price,
      item.seller,
      msg.sender,
      address(item.nft)
    );

    millimxNft = MillimxNft(address(item.nft));
    millimxNft.setIsOnMarket(item.tokenId, false);
  }

  function purchase(uint256 _itemId) external payable nonReentrant {
    Item storage item = items[_itemId];
    uint256 _price = item.price;
    require(_itemId > 0 && _itemId <= itemCount.current(), "Item doesn't exist");
    require(msg.value >= item.price , "Not enough ether to cover item price and market fee");
    require(!item.sold, "Sold out!");

    feeAccount.transfer(calculateFee(_price, feePercent)); // 회사가 먹는 거래수수료 (default : 5%)
    _price = _price - calculateFee(_price, feePercent);

    // 로열티 (default : 7.5%)
    uint256 totalRoyalty = calculateFee(item.price, royaltyPercent); // 로열티 총 금액 7.5%

    // 회사수수료(5%) + 로열티 (7.5%)를 빼고 난 87.5%를 판매자한테 준다.
    item.seller.transfer(_price - totalRoyalty);

    millimxNft = MillimxNft(address(item.nft));
    // 수익분배자들한테 수익률대로 전달함
    address[] memory splitAddress = millimxNft.getSplitAddress(item.tokenId);
    uint256[] memory splitPercent = millimxNft.getSplitPercent(item.tokenId);

    for(uint i=0; i< splitAddress.length; i++) {
      payable(splitAddress[i]).transfer(calculateFee(totalRoyalty, splitPercent[i]));
      totalRoyalty = totalRoyalty - calculateFee(totalRoyalty, splitPercent[i]);
    }

//    for(uint i=0; i< revenueDistributors[_itemId].length; i++) {
//      payable(revenueDistributors[_itemId][i]).transfer(calculateFee(_price, revenueDistributePercent[_itemId][i]));
//    }

//    feeAccount.transfer(calculateFee(item.price, feePercent));
//    item.seller.transfer(item.price - calculateFee(item.price, feePercent));

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

    millimxNft = MillimxNft(address(item.nft));
    millimxNft.setIsOnMarket(item.tokenId, false);
  }

  function calculateFee(uint256 _price, uint256 _percent) internal pure returns (uint256) {
    require((_price / 1000000) * 1000000 == _price, 'too small');
    return (_price * (_percent)) / 1000000;
  }

  function getNftToItemId(address _nft, uint256 _tokenId) public view returns (uint256) {
    return nftToItemId[_nft][_tokenId];
  }

  function setFeePercent (uint256 _feePercent) external onlyOwner {
    feePercent = _feePercent;
  }

  function getPrice(uint256 _itemId) public view returns (uint256) {
    return items[_itemId].price;
  }
}
