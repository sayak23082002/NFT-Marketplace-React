// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract NFT_Marketplace is ERC721URIStorageUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIds;
    CountersUpgradeable.Counter private _itemsSold;

    uint256 listingPrice;

    address payable owner;

    bool public initialized;

    mapping(uint256 => MarketItem) private idMarketItem;

    mapping(uint256 => address[]) private owners;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event idMarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can change the listing price");
        _;
    }

    function initialize(uint256 _listingPrice) initializer public {
        __ERC721_init("NFT Marketplace", "NFT");
        __ERC721URIStorage_init();
        listingPrice = _listingPrice;
        owner = payable(msg.sender);
    }

    //To update the listing price for NFT

    function updateListingPrice(uint256 _listingPrice) public payable onlyOwner {
        listingPrice = _listingPrice;
    }

    // To get the listing price for NFT

    function getListingPrice() public view returns (uint256){
        return listingPrice;
    }

    //To get all the owners

    function getAllOwners(uint256 tokenId) public view returns (address[] memory){
        return owners[tokenId];
    }



    //To create unique ID for every NFT

    function createToken(string memory tokenURI, uint256 price) public payable returns(uint256){
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        createMarketItem(newTokenId, price);

        return newTokenId;
    }

    //Create all the market items

    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, 'Price must be at least 1');
        require(msg.value == listingPrice, 'Price must be equal to listing price');

        idMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );

        owners[tokenId].push(msg.sender);

        _transfer(msg.sender, address(this), tokenId);

        emit idMarketItemCreated(tokenId, msg.sender, address(this), price, false);
    }

    //Function For Resale Token. To resale the previously bought NFT

    function reSellToken(uint256 tokenId, uint256 price) public payable{
        require(idMarketItem[tokenId].owner == msg.sender, "Only owner can sell this");
        require(msg.value == listingPrice, "Price must be equal to listing price");
        idMarketItem[tokenId].sold = false;
        idMarketItem[tokenId].price = price;
        idMarketItem[tokenId].seller = payable(msg.sender);
        idMarketItem[tokenId].owner = payable(address(this));

        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    //Function Create Market Sale. The main buying and saling process

    function createMarketSale(uint256 tokenId) public payable{
        uint256 price = idMarketItem[tokenId].price;

        require(msg.value >= price, "Please submit the asking price in order to complete the transaction");

        idMarketItem[tokenId].owner = payable(msg.sender);
        idMarketItem[tokenId].sold = true;

        _itemsSold.increment();

        owners[tokenId].push(msg.sender);

        _transfer(address(this), msg.sender, tokenId);

        payable(owner).transfer(listingPrice);

        uint256 remain = msg.value - price;

        uint256 actual = msg.value - remain;

        if(remain > 0){
            payable(msg.sender).transfer(remain);
        }

        payable(idMarketItem[tokenId].seller).transfer(actual);
    }

    //Get the unsold NFT Data

    function fetchMarketItem() public view returns(MarketItem[] memory) {
        
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for(uint256 i = 0; i < itemCount; i++){
            if(idMarketItem[i + 1].owner == address(this)){
                uint256 currenntId = i + 1;
                MarketItem storage currentItem = idMarketItem[currenntId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //Purchase Item

    function fetchMyNFT() public view returns(MarketItem[] memory) {
       uint256 totalCount = _tokenIds.current();
       uint256 itemCount = 0;
       uint256 currentIndex = 0;

        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i + 1].owner == msg.sender){
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i + 1].owner == msg.sender){
                uint256 currentId =  i + 1;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //Single userItems

    function fetchItemsListed() public view returns(MarketItem[] memory){
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i + 1].seller == msg.sender){
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);

        for(uint256 i = 0; i < totalCount; i++){
            if(idMarketItem[i + 1].seller == msg.sender){
                uint256 currentId = i + 1;

                MarketItem storage currentItem = idMarketItem[currentId];
                 items[currentIndex] = currentItem;
                 currentIndex += 1;
            }
        }
        return items;
    }
}
