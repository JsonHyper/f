// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "./ERC721A/ERC721A.sol";

contract ERC721 is ERC721A, Ownable, ReentrancyGuard, DefaultOperatorFilterer {
    using Strings for uint256;

    constructor() ERC721A("ERC721","E1") {} // name-symbol

    uint256 public maxSupply = 7777;
    uint256 public wlTotalMinted = 0;
    uint256 public publicTotalMinted = 0;

    uint256 public wlMintStartTime = 0;
    uint256 public wlMintEndTime = 0;
    uint256 public wlPrice = 0.04 ether;
    uint256 public maxMinted = 2;

    uint256 public pMintStartTime = 0;
    uint256 public pMintEndTime = 0;
    uint256 public pPrice = 0.05 ether;

    bytes32 public merkleRoot;
    bool public saleIsActive = true;

    function flipSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setWlTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        wlMintStartTime = _startTime;
        wlMintEndTime = _endTime;
    }
    function setWlPrice(uint256 _price) external onlyOwner {
        wlPrice = _price;
    }

    function setMaxMint(uint256 _max) external onlyOwner {
        maxMinted = _max;
    }

    function setPTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        pMintStartTime = _startTime;
        pMintEndTime = _endTime;
    }

    function setPPrice(uint256 _price) external onlyOwner {
        pPrice = _price;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    function setBaseURI(string calldata _uri) external onlyOwner {
        _baseTokenURI = _uri;
    }
    string public suffixUri = ".json";

    function setSuffixUri(string calldata _suffix) internal onlyOwner {
        suffixUri = _suffix;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        return
            bytes(_baseURI()).length != 0
                ? string(abi.encodePacked(_baseURI(), _tokenId.toString(), suffixUri))
                : "";
    }

    function ownerMint(uint256 _amount, address _to) external onlyOwner {
        _mint(_to, _amount);
    }

    function whitelistMint(bytes32[] calldata _merkleProof, uint256 _quantity)
    external
    payable
    nonReentrant
    {
        require(saleIsActive, "Not allowed to mint");
        // verify limit per account
        require(_quantity > 0, "Wrong amount of minting");
        require(_numberMinted(msg.sender) + _quantity <= maxMinted, "Exceed the limit of mint amount");
        // verify merkle
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "NOT incorporated in the whitelists");
        // verify start/end time
        require(block.timestamp > wlMintStartTime, "Wrong time for whitelist to mint");
        require(block.timestamp < wlMintEndTime, "Wrong time for whitelist to mint");
        // verify mint fee
        require(msg.value >= wlPrice * _quantity, "Insufficient value");
        // verify mint max count
        require(totalSupply() + _quantity <= maxSupply, "sold out");
        _safeMint(msg.sender, _quantity);
        wlTotalMinted += _quantity;
    }

    // feo
    function publicMint(uint256 _quantity) external payable nonReentrant {
        require(saleIsActive, "Not allowed to mint");
        require(_quantity > 0, "Wrong amount of minting");
        // verify start/end time
        require(block.timestamp > pMintStartTime, "Wrong time for public mint");
        require(block.timestamp < pMintEndTime, "Wrong time for public mint");
        // verify mint gas
        require(msg.value >= pPrice * _quantity, "Insufficient value");
        // verify mint max count
        require(totalSupply() + _quantity <= maxSupply, "sold out");
        _safeMint(msg.sender, _quantity);
        publicTotalMinted += _quantity;
    }

    // element
    uint256 public mintFromElementCount = 0;
    address public element;

    function getMintedQuantity(address _minter) public view returns (uint256) {
        return _numberMinted(_minter);
    }

    function updateElement(address _new) external onlyOwner {
        element = _new;
    }

    function mintFromElement(address _to, uint256 _quantity) external {
        require(msg.sender == element, "only partner allowed");
        require(saleIsActive, "Not allowed to mint");
        require(_quantity > 0, "Wrong amount of minting");
        // verify start/end time
        require(block.timestamp > pMintStartTime, "Wrong time for public mint");
        require(block.timestamp < pMintEndTime, "Wrong time for public mint");
        // verify mint max count
        require(totalSupply() + _quantity <= maxSupply, "sold out");
        publicTotalMinted += _quantity;
        mintFromElementCount += _quantity;
        _safeMint(_to, _quantity);
    }

    // Nswap
    uint256 public mintFromNswapCount = 0;

    uint256 public NswapMintlimit = 500;

    function updateNswapMintlimit(uint256 _limit) external onlyOwner {
        NswapMintlimit = _limit;
    }

    function mintFromNswap(uint256 _quantity) external payable nonReentrant {
        require(saleIsActive, "Not allowed to mint");
        require(_quantity > 0, "Wrong amount of minting");
        // verify start/end time
        require(block.timestamp > pMintStartTime, "Wrong time for public mint");
        require(block.timestamp < pMintEndTime, "Wrong time for public mint");
        // verify mint gas
        require(msg.value >= pPrice * _quantity, "Insufficient value");
        // verify mint max count
        require(mintFromNswapCount + _quantity <= NswapMintlimit, "sold out");
        require(totalSupply() + _quantity <= maxSupply, "sold out");
        publicTotalMinted += _quantity;
        mintFromNswapCount += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    function totalMinted() external view returns (uint256, uint256) {
        return (publicTotalMinted, wlTotalMinted);
    }

    function userCanMintNum(address _address) external view returns (uint256, uint256) {
        uint256 wlCanMintNum = maxMinted - _numberMinted(_address);
        uint256 pCanMintNum = maxSupply - wlTotalMinted;
        return (pCanMintNum, wlCanMintNum);
    }

    // PlanNft
    uint256 public mintFromPlanNft = 0;
    uint256 public planNftMintLimit = 400;

    function updatePlanNftMintLimit(uint256 _limit) external onlyOwner {
        planNftMintLimit = _limit;
    }

    function mintFromPlanNft(uint256 _quantity) external payable nonReentrant {
        require(saleIsActive, "Not allowed to mint");
        require(_quantity > 0, "Wrong amount of minting");
        // verify start/end time
        require(block.timestamp > pMintStartTime, "Wrong time for public mint");
        require(block.timestamp < pMintEndTime, "Wrong time for public mint");
        // verify mint gas
        require(msg.value >= pPrice * _quantity, "Insufficient value");
        // verify mint max count
        require(totalSupply() + _quantity <= maxSupply);
        require(_quantity + mintFromPlanNft <= plannftMintlimit, "sold out");
        publicTotalMinted += _quantity;
        mintFromPlanNft += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    receive() external payable {}

    function withdrawETH() external onlyOwner {
        payable(address(owner())).transfer(address(this).balance);
    }

    // os
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
    public
    override
    onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
    // end os
}
