// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTMarketplace is ERC721Holder, ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );
    event ListingCanceled(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external {
        require(price > 0, "Price must be greater than zero");
        require(!listings[nftContract][tokenId].active, "NFT already listed");

        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    function buyNFT(
        address nftContract,
        uint256 tokenId
    ) external payable nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "NFT not listed for sale");
        require(msg.value == listing.price, "Incorrect payment amount");

        listings[nftContract][tokenId].active = false;

        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Transfer to seller failed");

        IERC721(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit NFTSold(
            nftContract,
            tokenId,
            msg.sender,
            listing.seller,
            listing.price
        );
    }

    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.active, "NFT not listed for sale");
        require(listing.seller == msg.sender, "Not the seller");

        listings[nftContract][tokenId].active = false;

        IERC721(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        emit ListingCanceled(nftContract, tokenId, msg.sender);
    }

    function getListing(
        address nftContract,
        uint256 tokenId
    ) external view returns (address seller, uint256 price, bool active) {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.active);
    }
}
