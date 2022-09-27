//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.4;
//
//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";
//import "./MillimxNft.sol";
//
//contract Showtime is ReentrancyGuard, Ownable {
//  using Counters for Counters.Counter;
//  MillimxNft millimxNft;
//
//  address payable public immutable feeAccount; // 수수료를 받을 주소
//  uint256 public feePercent; // 팔때 받을 수수료
//  Counters.Counter public itemCount;
//
//  mapping (uint256 => Item) public items; // itemId => Item
//  mapping (address => mapping(uint => uint)) public nftToItemId; // [nft contract address] [tokenId]  => itemId (last enrolled)
//
//  mapping (uint256 => address[]) public showTimeDistributors;
//  mapping (uint256 => uint256[]) public showTimeDistributePercent;
//
//  struct Item {
//    uint256 itemId; // 판매 등록한 아이템 id
//    uint256 tokenId;  // 판매할 토큰 id
//    uint256 price;
//    address payable seller;
//    IERC721 nft;
//    bool sold;
//  }
//
//  event Registered (
//    uint256 itemId,
//    uint256 tokenId,
//    uint256 price,
//    address indexed seller,
//    address indexed nft
//  );
//
//  event Bought (
//    uint256 itemId,
//    uint256 tokenId,
//    uint256 price,
//    address indexed seller,
//    address indexed buyer,
//    address indexed nft
//  );
//
//  constructor (uint256 _feePercent) {
//    feeAccount = payable(msg.sender);
//    feePercent = _feePercent;
//  }
//
//  function register(IERC721 _nft, uint256[] memory _tokenIds, uint256[] memory _prices, address[] memory _distributors, uint256[] memory _distributePercents) external nonReentrant {
//
//    millimxNft = MillimxNft(address(_nft));
//
//    for(uint i=0; i< _tokenIds.length; i++) {
//      require(_prices[i] > 0, "Price must be greater than zero");
//      require(msg.sender == _nft.ownerOf(_tokenIds[i]), "Only owner can enroll");
//      require(!millimxNft.getIsOnMarket(_tokenIds[i]), "This is on the market");
//
//      _nft.approve(address(this), _tokenIds[i]);
//
//      itemCount.increment();
//      uint256 itemId = itemCount.current();
//      _nft.transferFrom(msg.sender, address(this), _tokenIds[i]);
//
//      items[itemId] = Item (
//        itemId,
//        _tokenIds[i],
//        _prices[i] * (10**15),
//        payable(msg.sender),
//        _nft,
//        false
//      );
//      emit Registered (
//        itemId,
//        _tokenIds[i],
//        _prices[i] * (10**15),
//        msg.sender,
//        address(_nft)
//      );
//
//      for(uint j=0; j< _distributors.length; j++) {
//        showTimeDistributors[_tokenIds[i]].push(_distributors[j]);
//        showTimeDistributePercent[_tokenIds[i]].push(_distributePercents[j]);
//      }
//
//      nftToItemId[address(_nft)][_tokenIds[i]] = itemId;
//      millimxNft.setIsOnMarket(_tokenIds[i], true);
//    }
//  }
//
//  function purchase(uint256 _itemId) external payable nonReentrant {
//    Item storage item = items[_itemId];
//    uint256 _price = item.price;
//    require(_itemId > 0 && _itemId <= itemCount.current(), "Item doesn't exist");
//    require(msg.value >= _price , "Not enough ether to cover item price and market fee");
//    require(!item.sold, "Sold out!");
//
//    // 회사가 먹는 거래수수료
//    feeAccount.transfer(calculateFee(_price, feePercent));
//
//    _price = _price - calculateFee(_price, feePercent);
//
//    // 수익분배자들한테 수익률대로 전달함
//    for(uint i=0; i< showTimeDistributors[item.tokenId].length; i++) {
//      payable(showTimeDistributors[item.tokenId][i]).transfer(calculateFee(_price, showTimeDistributePercent[item.tokenId][i]));
//    }
//
//    // update item to sold
//    item.sold = true;
//
//    // transfer nft to buyer
//    item.nft.safeTransferFrom(address(this), msg.sender, item.tokenId);
//
//    nftToItemId[address(item.nft)][item.tokenId] = 0;
//
//    // emit Bought event
//    emit Bought(
//      _itemId,
//      item.tokenId,
//      item.price,
//      item.seller,
//      msg.sender,
//      address(item.nft)
//    );
//
//    millimxNft = MillimxNft(address(item.nft));
//    millimxNft.setIsOnMarket(item.tokenId, false);
//  }
//
//  function calculateFee(uint256 _price, uint256 _percent) internal pure returns (uint256) {
//    require((_price / 1000000) * 1000000 == _price, 'too small');
//    return (_price * (_percent)) / 1000000;
//  }
//
//  function getNftToItemId(address _nft, uint256 _tokenId) public view returns (uint256) {
//    return nftToItemId[_nft][_tokenId];
//  }
//
//  function setFeePercent (uint256 _feePercent) external onlyOwner {
//    feePercent = _feePercent;
//  }
//
//  function getPrice(uint256 _itemId) public view returns (uint256) {
//    return items[_itemId].price;
//  }
//}
