// SPDX-License-Identifier: MIT
//0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
//0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
pragma solidity ^0.8.7;

// import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; // to work with COORDINATOR and VRF
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol"; // to use functionalities for Chainlink VRF
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";




contract TokenizedCommerce is ERC1155 /*AccessControl*/ ,VRFConsumerBaseV2 , ERC1155Holder{ 
   IERC20 token;
  /**
  * @notice Enum for Contract state -> to let user enter call some functions or not
  */
  enum ContractState {   
    Active,
    Inactive
  }
    
  /**
  * @notice Struct for Items on the Marketplace
  */
  uint private _marketCount;
  struct itemOnSale{
        uint tokenId;
        uint marketItemId;
        uint price;
        address payable seller;
        bool sold;
  }

  /// @notice tokens
  // IERC721 COMMERCE_NFT;
  // address public constant i_NFTAddress = the address of the NFT contract;
  
  
  /// @notice Standard variables
  // bytes32 public constant ADMIN_ROLE = 0x00;
  address private _owner;
  uint256 private s_maxTotalSupply;
  uint256 private s_tokenCount;
  uint256 public casePrice; 
  bool public contractActive = true;
  ContractState public s_contractState;
  itemOnSale[] _marketItems;

  /// @notice VRF Variables
  VRFCoordinatorV2Interface public immutable i_vrfCoordinator; 
  bytes32 public immutable i_gasLane;
  uint64 public immutable i_subscriptionId;
  uint32 public immutable i_callbackGasLimit;
  uint16 public constant REQUEST_CONFIRMATIONS = 3; 
  uint32 public constant NUM_WORDS = 2; 
  uint256 public s_randomWord; // random Number we get from Chainlink VRF
  
  /// @notice Mappings

  mapping(uint => uint) private s_maxSupply;
  mapping (uint256 => string) private s_uris; 

  /// @notice Events
  event CaseOpened(address user, uint256 casePrice, uint256 item);
  event casePriceChanged(uint256 newPrice);
  event itemExchanged(address user, uint256 tokenId);
  event sellingItem(address user, uint256 tokenId, uint256 price);
  event itemBought(address buyer, address seller, uint256 marketItemId, uint256 price);
  event unListedItem(address owner, uint256 marketItemId);
  event itemPriceChanged(address owner, uint256 marketItemId, uint256 oldPrice, uint256 newPrice);
  
  /// @notice Modifiers
  /// @notice Check that person calling a function is the owner of the Contract
  modifier onlyOwner() {
      require(msg.sender == _owner, "User is not the owner");
      _;
  }

  /// @notice Check that user is Member 
  // modifier onlyVIP() {
  //     require(isVip(msg.sender), "User is not golden member");
  //     _;
  // }

  // modifier onlyOwnerOrAdmin() {
  //   require(_isOwnerOrAdmin(msg.sender), "User is not the Owner or an Admin");
  //   _;
  // }

  /// @notice Check if contract state is Active
  modifier contractIsActive() {
    require(s_contractState == ContractState.Active, "Contract is not active at this moment");
    _;
  }

  constructor(address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit ,address tokenAddress) 
  VRFConsumerBaseV2(vrfCoordinatorV2)
  ERC1155(""){
    casePrice = 100;
    token = IERC20(tokenAddress);
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); 
    i_gasLane = gasLane; 
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit; 

    /**
    * Initialization of  contract variables
    */
    // COMMERCE_NFT = IERC721(commerceNFTAddress);

    _owner = msg.sender;
    s_tokenCount = 0;
    casePrice = 0;
    s_contractState = ContractState.Active;



    _mintSupply(address(this), 100000);   
    _mintSupply(address(this), 80000); 
    _mintSupply(address(this), 50000); 
    _mintSupply(address(this), 30000); 
    _mintSupply(address(this), 10000); 
    _mintSupply(address(this), 1000); 

  
  }

  /** 
  * @notice Need to override supportsInterface function because Contract is ERC1155 and AccessControl
  */
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver/*, AccessControl*/) returns (bool) {
    return super.supportsInterface(interfaceId);
  }


  // FUNCTIONS RELATED WITH THE CASE

  /**
  * @notice Change price of the box
  * @dev Only callable by the Owner
  */
  // function setCasePrice(uint256 price) public onlyOwnerOrAdmin {
  //   casePrice = price;
  //   emit casePriceChanged(price);
  // }

  /**
  * @notice View case price
  */
  function getCasePrice() public view returns(uint256) {
    return casePrice;
  }

  /**
  * @notice Used to get an actually Random Number -> to pick an item when openning a case
  * @dev Uses Chainlink VRF -> call requestRandomWords method by using o_vrfCoordinator object
  * set as internal because is going to be called only when a case is opened
  */
  function _randomNumber() public returns(uint256) {
    uint256 s_requestedNumber = i_vrfCoordinator.requestRandomWords(i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS);
    return s_requestedNumber;
   
  }

  /**
  * @notice Function to actually pick a winner 
  * @dev 
  * - randomWords -> array of randomWords
  */
  function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override {
    s_randomWord = randomWords[0]; // just in case random number is very long we apply modular function 
  }

   /**
  * @notice Function used to 'open a case' and get an item
  * @dev 
  * - Should check that msg.value is bigger than casePrice
  * - Should transfer msg.value to the contract
  * - Internally calls randomNumber() 
  * - Apply modular function for the randomNumber to be between 0 and totalSupply of items
  * - Should choose an item
  */
  function openCase() public  payable {  /*onlyVIP contractIsActive*/
    require(msg.value==casePrice);
    uint256 randomNumber = _randomNumber()  % s_maxTotalSupply;
    uint256 totalCount = 0;
    uint256 item;

    for(uint256 i = 0 ; i < s_tokenCount; i++) {
      uint256 _newTotalCount = totalCount + s_maxSupply[i] ;
      if(randomNumber > totalCount) {
        totalCount = _newTotalCount;
      }else {
        item = i-1;
        if(balanceOf(address(this),item)==0){
          for(uint256 j = item-1; j >= 0; j--){
            if (balanceOf(address(this),j)>0){
              item = j;
              break;
            }
          }
        }
        _safeTransferFrom(address(this), msg.sender, item , 1,"");
        break;
      }
    }
    emit CaseOpened(msg.sender, casePrice, item);
  }


  // FUNCTIONS RELATED TO ITEMS

  /**
  * @notice Returns maxSupply of specific item (by tokenId)
  * @dev - Getter of s_maxSupply mapping
  */
  function supplyOfItem(uint256 tokenId) public view returns(uint) {
    return s_maxSupply[tokenId];
  }

  /**
  * @notice Check that item exists (by tokenId)
  */
  function _itemExists(uint256 tokenId) internal view returns (bool) {
    require(s_maxSupply[tokenId] > 0);
    return true;
  }

  /**
  * @notice Calculate chance of receiving an specific item
  * @dev - Requires that tokenId exists (item is listed)
  * - chance is calculated as item supply divided by total items supply
  */
  function rarityOfItem(uint256 tokenId) public virtual view returns(uint256) {
    require(_itemExists(tokenId));
    uint256 result =   s_maxTotalSupply/ s_maxSupply[tokenId];
    return result;
  }

  /**
  * @notice Returns all the items inside the user's inventory (Could be used by the
  * user to check his inventory or to check someone else inventory by address)
  * @dev Copy users inventory in an empty array and returns it
  */
  function viewItems(address owner) public view returns(uint256[] memory) { 
    uint256[] memory inventory = new uint [](s_tokenCount );
    for(uint256 i=0 ; i<inventory.length; i++) {
      inventory[i]=balanceOf(owner,i);
    }
    return inventory;
  }

  /**
  * @notice List a new item to the avaliable collection
  * @dev Only callable by the Owner
  */
  function listItem(uint256 itemSupply) public  {
    _mintSupply(address(this), itemSupply);
  }

  /**
  * @notice Mint supply tokens of each Item
  * @dev Declared internal because it is called inside the contructor
  * - call _mint function
  * - call set maxSupply function
  * - updates TotalMaxSupply of Items
  * - updates s_tokenCount -> Each items has associated an Id (e.g: Jeans -> Id: 0, Hoddie -> Id: 1,
  * we increment s_tokenCount so next time we call _mintSupply a new type of item is going to be minted)
  * - The items (tokens are minted by this contract and deposited into this contract address)
  */
  function _mintSupply(address receiver, uint256 amount) internal {
      _mint(receiver, s_tokenCount, amount, "");
      _setMaxSupply(s_tokenCount, amount);
      s_maxTotalSupply += amount;
      s_tokenCount += 1;
  }

  /**
  * @notice Function used to set maxSupply of each item
  */
  function _setMaxSupply(uint256 tokenId, uint256 amount) internal {
      s_maxSupply[tokenId] = amount;
  }


  // FUNCTIONS RELATED TO THE "MARKETPLACE"

  /**
  * @notice Function used to sell an item on the marketplace
  * @dev
  * - Needs to check balanceOf item trying to be sold
  * - Needs to transfer item 
  * - Update marketItems array
  * - Emit event 
  */
  function sellItem(uint256 tokenId, uint256 price) public {
    require(balanceOf(msg.sender, tokenId) > 0, "Item not found.");

    _safeTransferFrom(msg.sender, address(this), tokenId, 1 ,"");
    _marketItems.push(
      itemOnSale(
        tokenId,
        _marketCount,
        price,
        payable(msg.sender),
        false
      )
    );
    _marketCount++;
    emit sellingItem(msg.sender, tokenId, price);
  }
  /**
  * 
@notice
 Function used to unlist an item from marketplace
  * 
@dev

  * - Needs to check that user is trying to unlist an item he owns
  * - Needs to transfer item from contract to user address
  * - Update item's sold variable
  */
  function unListItem(uint256 marketItemId) public {
    require(_marketItems[marketItemId].seller == msg.sender, "You are not the owner of this item.");
    _safeTransferFrom(address(this), msg.sender, marketItemId, 1, "");
    _marketItems[marketItemId].sold = true;
  }

  /**
  * @notice Function used to exchange a token item for a real physical clothe.
  */
  function exchangeItem(uint256 tokenId) public {
    require(balanceOf(msg.sender, tokenId) > 0);
     _burn(msg.sender, tokenId, 1);
     s_maxSupply[tokenId] -= 1;
     s_maxTotalSupply -=1;
     emit itemExchanged(msg.sender, tokenId);
  }

  /**
  * @notice Function used to buy an item on the marketplace
  * @dev
  * - Needs to transfer tokens from buyer to seller
  * - Needs to transfer item from seller to buyer
  * - Update sold attribute from array
  * - Emit event 
  */
  function buyItem(uint256 marketItemId) public payable {
    
    itemOnSale memory item = _marketItems[marketItemId];
    require(msg.value==item.price);
    require(msg.sender!=item.seller);
    require(msg.value==item.price);
    require(item.sold==false);
    payable(item.seller).transfer(item.price);
    _safeTransferFrom(address(this), msg.sender, item.tokenId, 1 ,"");
    _marketItems[marketItemId].sold = true;
    emit itemBought(msg.sender, item.seller, marketItemId, item.price);
  }

  /**
  * @notice Functions used to return items that are currently on sale
  */
  function getMarketItem(uint marketItemId) public returns(itemOnSale memory){
    return _marketItems[marketItemId];
  }
  /**
  * 
@notice
 Function used to change price from item listed 
  * 
@dev

  * - Needs to check that user is trying to unlist an item he owns
  * - Needs to update price status
  * - Emit event
  */
  function changeItemPrice(uint256 marketItemId, uint256 newPrice) public {
    require(_marketItems[marketItemId].seller == msg.sender, "You are not the owner of this item.");
    uint256 oldPrice = _marketItems[marketItemId].price;
    _marketItems[marketItemId].price = newPrice;
    emit itemPriceChanged(msg.sender, marketItemId, oldPrice, newPrice);
  }

  /**
  * 
@notice
 Function used to unlist an item from marketplace
  * 
@dev

  * - Needs to check that user is trying to unlist an item he owns
  * - Needs to transfer item from contract to user address
  * - Update item's sold variable
  */
  function unListItem(uint256 marketItemId) public {
    require(_marketItems[marketItemId].seller == msg.sender, "You are not the owner of this item.");
    _safeTransferFrom(address(this), msg.sender, marketItemId, 1, "");
    _marketItems[marketItemId].sold = true;
    emit unListedItem(msg.sender, marketItemId);
  }
  function getItemsOnSale() public view returns(itemOnSale[] memory) {
    uint arrayLength;
    
    for(uint i=0; i<_marketItems.length;i++){
      itemOnSale memory  item = _marketItems[i];
      if(item.sold==false){
        arrayLength+=1;
      }
    }
    itemOnSale[] memory items = new itemOnSale[](arrayLength);
    uint indexCount;
    for(uint256 i = 0; i < _marketItems.length; i++){
      itemOnSale memory  item = _marketItems[i];
      if(item.sold==false){
        items[indexCount]=item;
        indexCount++;

      }
    }
    return items;
  }

  // FUNCTIONS RELATED TO "USERS"

  /**
  *Requires that user owns an NFT of the company
  */
  // function isVip(address user) public view returns(bool){
  //   require(COMMERCE_NFT.balanceOf(user) > 0);
  //   return true;
  // }

  /**
  * @notice Check if user is owner of the Contract or has admin role
  * @dev Only callable by the Owner
  */
  // function _isOwnerOrAdmin(address user) internal view returns (bool) {
  //     require(_owner == user || hasRole(ADMIN_ROLE, user));
  //     return true;
  // }

 

  /**
  * @notice Set new Admin
  * @dev Only callable by the Owner
  */
  // function setAdmin(address _newAdmin) public onlyOwner {
  //   _setupRole(ADMIN_ROLE, _newAdmin);
  // }

  // FUNCTIONS RELATED WITH THE CONTRACT

  /**
  * @notice Change contract state from Active to Inactive and viceversa
  * @dev Only callable by the Owner or an admin
  */
  // function flipContractState() public onlyOwnerOrAdmin {
  //   if (s_contractState == ContractState.Active) {
  //     s_contractState = ContractState.Inactive;
  //   }else {
  //     s_contractState = ContractState.Active;
  //   }
  // }

  // FUNCTIONS RELATED TO ERC1155 TOKENS

  /**
  * @notice Used to return token URI by inserting tokenID
  * @dev - returns information stored in s_uris mapping
  * - Any user can check this information
  */
  // function uri(uint256 tokenId) override public view returns (string memory) {
  //   return(s_uris[tokenId]);
  // }

  // /**
  // * @notice Used to set tokenURI to specific item 
  // * @dev - Only Owner or Admins can call this function
  // * - Need to specify:
  // *  - tokenId: specific item you want to set its uri
  // *  - uri: uri wanted to be set
  // */
  // function setTokenUri(uint256 tokenId, string memory _uri) public onlyOwnerOrAdmin {
  //       require(bytes(s_uris[tokenId]).length == 0, "Can not set uri twice"); 
  //       s_uris[tokenId] = _uri; 
  // }

  
  // FUNCTIONS RELATED TO FUNDS
  
  /**
  * @notice Used to withdraw specific amount of funds
  * @dev 
  * - Only owner is able to call this function
  * - Should check that there are avaliable funds to withdraw
  * - Should specify the wallet address you want to transfer the funds to
  * - Should specify the amount of funds you want to transfer
  // */
  // function withdrawFunds(address wallet, uint256 amount) public onlyOwner {
  //   require(address(this).balance >=amount , "Not enough funds to withdraw");
  //   payable(wallet).transfer(amount);
  // }

  // /**
  // * @notice Used to withdraw ALL funds
  // * @dev 
  // * - Only owner is able to call this function
  // * - Should check that there are avaliable funds to withdraw
  // * - Should specify the wallet address you want to transfer the funds to
  // */
  // function withdrawAllFunds(address wallet) public onlyOwner {
  //   require(address(this).balance > 0, "No funds to withdraw");
  //   payable(wallet).transfer(address(this).balance);
  // }

  // /// @notice Receive function
  // receive() external payable {
  // }
}