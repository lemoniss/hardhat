// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MillimxNft.sol";

contract Marketplace is ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;
  MillimxNft millimxNft;

  address payable public feeAccount; // 수수료를 받을 주소
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

  event MarketTxFee(
    uint256 tokenId,
    address indexed millimxAddress,
    uint256 feePercent,
    uint256 feePrice
  );

  event Royalty(
    uint256 itemId,
    uint256 tokenId,
    address indexed royaltyAddress,
    uint256 royaltyPercent,
    uint256 royaltyPrice
  );

  event Sales(
    uint256 itemId,
    uint256 tokenId,
    uint256 price,
    address indexed seller,
    address indexed buyer
  );

  constructor (uint256 _feePercent, uint256 _royaltyPercent) {
    feeAccount = payable(0x75b6467eFdb4e39C094c17795a0EBd2F76D5C142);
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
    require(millimxNft.getIsOnMarket(item.tokenId), "This is not on the market");
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

    feeAccount.transfer(calculateFee(_price, feePercent)); // 회사가 먹는 거래수수료 (default : 5%)   거래소 구매 수수료 지갑
    emit MarketTxFee(
      item.tokenId,
      feeAccount,
      feePercent,
      calculateFee(_price, feePercent)
    );

    _price = _price - calculateFee(_price, feePercent); // 95% 남음

    // 로열티 (default : 7.5%)
    uint256 totalRoyalty = calculateFee(_price, royaltyPercent); // 로열티 총 금액 7.5%

    // 회사수수료(5%) + 로열티 (7.5%)를 빼고 난 87.5%를 판매자한테 준다.
    item.seller.transfer(_price - totalRoyalty);
    emit Sales(
      _itemId,
      item.tokenId,
      _price - totalRoyalty,
      item.seller,
      msg.sender
    );

    millimxNft = MillimxNft(address(item.nft));
    // 수익분배자들한테 수익률대로 전달함
    address[] memory splitAddress = millimxNft.getSplitAddress(item.tokenId);
    uint256[] memory splitPercent = millimxNft.getSplitPercent(item.tokenId);

    for(uint i=0; i< splitAddress.length; i++) {
      payable(splitAddress[i]).transfer(calculateFee(totalRoyalty, splitPercent[i]));
      emit Royalty(
        _itemId,
        item.tokenId,
        splitAddress[i],
        splitPercent[i],
        calculateFee(totalRoyalty, splitPercent[i])
      );
    }

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

  function setFeeAccount (address _feeAccount) external onlyOwner {
    require(_feeAccount != address(0), "Market FeeAccount is the zero address");
    feeAccount = payable(_feeAccount);
  }

  function setFeePercent (uint256 _feePercent) external onlyOwner {
    feePercent = _feePercent;
  }

  function setRoyaltyPercent (uint256 _royaltyPercent) external onlyOwner {
    royaltyPercent = _royaltyPercent;
  }

  function getPrice(uint256 _itemId) public view returns (uint256) {
    return items[_itemId].price;
  }

  // 출금
  function withdraw() external payable onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }
}
