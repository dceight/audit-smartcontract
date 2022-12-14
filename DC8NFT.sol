//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc1155](https://docs.openzeppelin.com/contracts/3.x/erc1155)
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DC8NFT is ERC1155URIStorage {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsListed;
    string public constant name = "DC8 NFT";
    uint256 constant publicPackagePrice = 0.08 ether;
    uint256 constant privatePackagePrice = 0.06 ether;
    uint256 constant initPrice = 0.08 ether;
    uint256 constant totalSupply = 3000;
    bool private allowSale = false;
    bool private allowOpenPkg = false;
    bool private privateSale = true;
    address private hostWallet;

    string private domain = "https://core.dc8.io/meta/details/";
    uint256 constant PACKAGEs = 100000;
    uint256 constant PACKAGEx1_PUBLIC = 1;
    uint256 constant PACKAGEx5_PUBLIC = 2;
    uint256 constant PACKAGEx10_PUBLIC = 3;
    uint256 constant PACKAGEx50_PUBLIC = 4;
    uint256 constant PACKAGEx1_PRIVATE = 5;
    uint256 constant PACKAGEx2_PRIVATE = 6;

    constructor() ERC1155("DC8 NFT") {
        hostWallet = msg.sender;
        uint256 tokenId = 0;
        setURI(tokenId, string(abi.encodePacked(domain, tokenId.toString())));
        _mint(msg.sender, tokenId, 1, "0x0");
    }

    mapping(uint256 => MarketItem) private idToMarketItem;
    mapping(uint256 => PackageItem) private idToPackageItem;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 initPrice;
        uint256 price;
    }
    struct PackageItem {
        uint256 packageId;
        uint256 amount;
        uint256 quantity;
    }
    event packageEvents(uint256 package, uint256 price, string mode); // buy - mint - open
    event nftEvents(uint256 tokenId, uint256 price, string mode); // list - purchase - offer

    function ownerOf(uint256 tokenId) external view returns (bool) {
        return this.balanceOf(msg.sender, tokenId) != 0;
    }

    function setURI(uint256 tokenId, string memory tokenURI) public {
        _setURI(tokenId, tokenURI);
    }

    function allowRule(uint256 mode, bool allowed) public payable {
        require(msg.sender == hostWallet, "Only host can allow it");
        if (mode == 1) {
            // sale
            allowSale = allowed;
        } else if (mode == 2) {
            // open package
            allowOpenPkg = allowed;
        } else {
            // private sale
            privateSale = allowed;
        }
    }

    function getPackage(uint256 pkCode) private pure returns (PackageItem memory) {
        uint256 pkgToken = PACKAGEs + pkCode;
        PackageItem memory pkg = PackageItem(pkgToken, 0, 1);
        pkg.packageId = pkgToken;
        if (pkCode == PACKAGEx1_PUBLIC) {
            pkg.quantity = 1;
        } else if (pkCode == PACKAGEx5_PUBLIC) {
            pkg.quantity = 5;
        } else if (pkCode == PACKAGEx10_PUBLIC) {
            pkg.quantity = 10;
        } else if (pkCode == PACKAGEx50_PUBLIC) {
            pkg.quantity = 50;
        } else if (pkCode == PACKAGEx1_PRIVATE) {
            pkg.quantity = 1;
        } else if (pkCode == PACKAGEx2_PRIVATE) {
            pkg.quantity = 2;
        } else {
            revert("No package.");
        }
        return pkg;
    }

    function fetchMyPackages(address payable user) public view returns (PackageItem[] memory) {
        PackageItem[] memory items = new PackageItem[](6);
        for (uint256 i = 0; i < 6; i++) {
            items[i].packageId = 100000 + i + 1;
            items[i].amount = this.balanceOf(user, 100000 + i + 1);
        }
        return items;
    }

    function buyPublicPackage(uint256 pkCode) public payable {
        require(privateSale == false && allowSale == true, "No sale now");
        require(pkCode <= 4 && pkCode >= 1, "No package");
        require(msg.sender != hostWallet, "You are host");
        PackageItem memory pkg = getPackage(pkCode);
        uint256 price = pkg.quantity * publicPackagePrice;
        require(msg.value >= price, "Pkg not free");
        buyPkg(pkg);
        payable(hostWallet).transfer(msg.value);
    }

    function buyPrivatePackage(uint256 pkCode) public payable {
        require(privateSale == true && allowSale == true, "No sale now");
        require(pkCode <= 6 && pkCode >= 5, "No package.");
        require(msg.sender != hostWallet, "You are host");
        PackageItem memory pkg = getPackage(pkCode);
        uint256 price = pkg.quantity * privatePackagePrice;
        require(msg.value >= price, "Pkg not free");
        buyPkg(pkg);
        payable(hostWallet).transfer(msg.value);
    }
    function buyPkg(PackageItem memory pkg) private {
        uint256 nextItemCount = pkg.quantity + _tokenIds.current();
        require(nextItemCount <= totalSupply, "Total supply has reached.");
        _mint(msg.sender, pkg.packageId, 1, "");
        if (privateSale == true) {
            emit packageEvents(pkg.packageId, msg.value, "BUY_PRIVATE_PKG");
        } else {
            emit packageEvents(pkg.packageId, msg.value, "BUY_PUBLIC_PKG");
        }
    }


    function openPackage(uint256 pkCode) public payable {
        require(allowOpenPkg == true, "Not allow openPkg");
        require(pkCode <= 6 && pkCode >= 1, "No package");
        PackageItem memory pkg = getPackage(pkCode);
        require(this.balanceOf(msg.sender, pkg.packageId) > 0, "You have no package.");
        _burn(msg.sender, pkg.packageId, 1);
        payable(hostWallet).transfer(msg.value);
        mintNFTs(pkg.quantity);
        emit packageEvents(pkg.packageId, msg.value, "OPEN_PKG");
    }

    function modifyItem(
        uint256 tokenId,
        address payable myOwner,
        address payable _seller,
        address payable _owner
    ) private {
        require(
            idToMarketItem[tokenId].owner == myOwner,
            "Only item owner can perform this operation"
        );
        idToMarketItem[tokenId].seller = _seller;
        idToMarketItem[tokenId].owner = _owner;
    }

    function listNft(uint256 tokenId, uint256 price) public payable {
        modifyItem(tokenId, payable(msg.sender), payable(msg.sender), payable(hostWallet));
        idToMarketItem[tokenId].price = price * 1e18;
        _itemsListed.increment();
        payable(hostWallet).transfer(msg.value);
        safeTransferFrom(payable(msg.sender), payable(hostWallet), tokenId, 1, "");
        emit nftEvents(tokenId, msg.value, "LIST_NFT");
    }

    function cancelListing(uint256 tokenId) public payable {
        require(
            idToMarketItem[tokenId].seller == payable(msg.sender),
            "Only item owner can perform this operation"
        );
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(msg.sender);
        _itemsListed.decrement();
        payable(hostWallet).transfer(msg.value);
        safeTransferFrom(payable(hostWallet), payable(msg.sender), tokenId, 1, "");
        emit nftEvents(tokenId, msg.value, "CANCEL_LISTING");
    }

    function purchaseNft(uint256 tokenId) public payable {
        uint256 price = idToMarketItem[tokenId].price;
        require(msg.value >= price, "Your price is invalid");
        address seller = idToMarketItem[tokenId].seller;
        modifyItem(tokenId, payable(hostWallet), payable(msg.sender), payable(msg.sender));
        _itemsListed.decrement();
        uint256 purchaseBonus = (msg.value * 10) / 100;
        uint256 remain = msg.value - purchaseBonus;
        safeTransferFrom(payable(hostWallet), idToMarketItem[tokenId].owner, tokenId, 1, "");
        payable(hostWallet).transfer(purchaseBonus);
        payable(seller).transfer(remain);
        emit nftEvents(tokenId, remain, "PURCHASE_NFT");
    }

    function transferNft(uint256 tokenId, address receiver) public payable {
        modifyItem(tokenId, payable(msg.sender), payable(receiver), payable(receiver));
        safeTransferFrom(payable(msg.sender), payable(receiver), tokenId, 1, "");
        emit nftEvents(tokenId, msg.value, "TRANSFER_NFT");
    }

    function adminMintNFTs(uint256 _quantity) public {
        require(msg.sender == hostWallet, "You are not host");
        mintNFTs(_quantity);
    }

    function mintNFTs(uint256 _quantity) private {
        uint256[] memory ids = new uint256[](_quantity);
        uint256[] memory amounts = new uint256[](_quantity);
        uint256 nextItemCount = _quantity + _tokenIds.current();
        require(nextItemCount <= totalSupply, "Total supply has reached.");
        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            ids[i] = tokenId;
            amounts[i] = 1;
            string memory tokenURI = string(abi.encodePacked(domain, tokenId.toString()));
            setURI(tokenId, tokenURI);
            idToMarketItem[tokenId] = MarketItem(
                tokenId,
                payable(msg.sender),
                payable(msg.sender),
                initPrice,
                0
            );
        }
        _mintBatch(msg.sender, ids, amounts, "0x0");
    }

    function fetchMyNftIDs(address sender) public view returns (uint256[] memory) {
        uint256 j = 0;
        uint256 total = _tokenIds.current();
        uint256[] memory itemIds = new uint256[](total);
        for (uint256 i = 0; i < total; i++) {
            if (idToMarketItem[i + 1].owner == payable(sender)) {
                itemIds[j] = i + 1;
                j += 1;
            }
        }
        return itemIds;
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }
}
