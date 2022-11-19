//Best practices -
//imports
//structs
//events
//mappings
//constructors
//helper functions
//main functions

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds; //_tokenIds variable has the most recent minted tokenId
    Counters.Counter private _itemsSold; //tracks number of items sold on marketplace
    uint256 marketplaceFee = 0.01 ether; //marketplace fee for listing NFT

    //Struct mapped to token ID of NFT used to retrieve info
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed; //NFT is listed on marketplace by default
    }

    //the event emitted when a token is successfully listed
    event TokenListedSuccess(
        uint256 indexed tokenId,
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed
    );

    event WithdrawSaleFunds(address owner, uint256 amountWithdrawn);

    //This mapping maps tokenId to token info and is helpful when retrieving details about a tokenId
    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("NFTMarketplace", "NFTM") {}

    function updateMarketplaceFee(uint256 _newMarketplaceFee)
        public
        payable
        onlyOwner
    {
        marketplaceFee = _newMarketplaceFee;
    }

    function getMarketplacePrice() public view returns (uint256) {
        return marketplaceFee;
    }

    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getListedTokenForId(uint256 tokenId)
        public
        view
        returns (ListedToken memory)
    {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    //Listing price

    function createToken(string memory tokenURI, uint256 price)
        public
        returns (uint256)
    {
        require(
            price > marketplaceFee,
            "Price must be higher than the market fee"
        );

        //Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId); //Mint the NFT with tokenId newTokenId to the address who called createToken

        _setTokenURI(newTokenId, tokenURI); //Maps the tokenId to the tokenURI (which is an IPFS URL with the NFT metadata)

        createListedToken(newTokenId, price); //Helper function to update Global variables and emit an event

        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        //Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        );
        //transfer ownership of NFT from creator to smart contract
        _transfer(msg.sender, address(this), tokenId);
        //Emit the event for successful transfer. The frontend parses this message and updates the end user
        emit TokenListedSuccess(
            tokenId,
            address(this),
            msg.sender,
            price,
            true
        );
    }

    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint256 currentIndex = 0;
        uint256 currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for (uint256 i = 0; i < nftCount; i++) {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex = currentIndex + 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;
        uint256 currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //transfers ownership and value, updates mapping
    function executeSale(uint256 tokenId) public payable {
        uint256 price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;
        uint256 bidPrice = msg.value;
        require(
            bidPrice == price,
            "Please submit the asking price in order to complete the purchase"
        );

        //token details get updated
        idToListedToken[tokenId].currentlyListed = false;
        idToListedToken[tokenId].seller = payable(msg.sender);
        _itemsSold.increment();

        _transfer(address(this), msg.sender, tokenId); //transfers the token to the msg.sender (new owner)
        //approve(address(this), tokenId); //approves the marketplace to sell NFTs on your behalf
        uint256 amountToSeller = bidPrice - marketplaceFee;

        payable(seller).transfer(amountToSeller); //Transfer the proceeds from the sale to the seller of the NFT
    }

    function withdrawSaleFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        //fetch eth balance
        payable(owner()).transfer(balance);

        emit WithdrawSaleFunds(owner(), balance);
    }

    //We might add a resell token function in the future
    //In that case, tokens won't be listed by default but users can send a request to actually list a token
    //Currently NFTs are listed by default
}
