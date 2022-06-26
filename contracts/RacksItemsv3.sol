// SPDX-License-Identifier: MIT
// 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
// 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f

pragma solidity ^0.8.0;
import "./IRacksItems.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol"; // define roles
import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155.sol"; // erc1155 tokens
import "../node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol"; // contract should be ERC1155 holder to receive ERC1155 tokens
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; // to instanciate MrCrypto object
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol"; // to work with RacksToken
import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; // to work with COORDINATOR and VRF
import "../node_modules/@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol"; // to use functionalities for Chainlink VRF

contract RacksItemsv3 is  ERC1155, ERC1155Holder, IRacksItems, AccessControl, VRFConsumerBaseV2 { // VRFv2SubscriptionManager
   
  /**
  * @notice Enum for Contract state -> to let user enter call some functions or not
  */
  enum ContractState {   
    Active,
    Inactive
  }



  /// @notice tokens
  IERC721Enumerable MR_CRYPTO;
  IERC20 racksToken;
  
  /// @notice Standard variables
  bytes32 public constant ADMIN_ROLE = 0x00;
  address private _owner;
  uint256 public totalSupply;
  uint256 private s_tokenCount;
  uint256 private _marketCount;
  uint256 public casePrice; // Change to RacksToken
  bool public contractActive = true;
  ContractState public s_contractState;
  itemOnSale[] _marketItems;
  address [] s_racksMembers;

  /// @notice VRF Variables
  VRFCoordinatorV2Interface public immutable i_vrfCoordinator; 
  bytes32 public immutable i_gasLane;
  uint64 public immutable i_subscriptionId;
  uint32 public immutable i_callbackGasLimit;
  uint16 public constant REQUEST_CONFIRMATIONS = 3; 
  uint32 public constant NUM_WORDS = 2; 
  uint256 public s_randomWord; // random Number we get from Chainlink VRF
  
  /// @notice Mappings
  mapping(address => bool) private s_gotRacksMembers;
  mapping(uint256 => uint256) private s_maxSupply;
  mapping (uint256 => string) private s_uris; 
  mapping (address => caseTicket) private s_caseTickets;
  mapping (address => mapping(uint256=> uint256)) s_marketInventory;

  /// @notice Modifiers
  /// @notice Check that person calling a function is the owner of the Contract
  modifier onlyOwner() {
    require(msg.sender == _owner, "User is not the owner");
      _;
  }

  /// @notice Check that user is Owner or Admin
  modifier onlyOwnerOrAdmin() {
    require(_isOwnerOrAdmin(msg.sender), "User is not the Owner or an Admin");
    _;
  }

  /// @notice Check that user is Member and owns at least 1 MrCrypto
  modifier onlyVIP() {
    require(isVIP(msg.sender), "User is not RacksMembers or does not owns a MrCrypto");
      _;
  }

  /**  @notice Check that user is owns at least 1 ticket for opening case (used in case user
  * does not own a MrCrypto or RacksMember and buys a ticket from another user)
  */
  modifier ownsTicket(address user) {
    require(_ownsTicket(user));
    _;
  }


  /**  @notice Check that there is at least 1 item avaliable so the user can open a case for example
  */
  modifier supplyAvaliable() {
    require(totalSupply > 0, "There are no items avaliable");
    _;
  }

  /// @notice Check if contract state is Active
  modifier contractIsActive() {
    require(s_contractState == ContractState.Active, "Contract is not active at this moment");
    _;
  }

  constructor(address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit, address _racksTokenAddress, address _MockMrCryptoAddress) 
  VRFConsumerBaseV2(vrfCoordinatorV2)
  ERC1155(""){
    /**
    * Initialization of Chainlink VRF variables
    */
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); 
    i_gasLane = gasLane; 
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit; 

    /**
    * Initialization of RacksItem contract variables
    */
    MR_CRYPTO = IERC721Enumerable(_MockMrCryptoAddress);
    racksToken = IERC20(_racksTokenAddress);
    _owner = msg.sender;
    s_tokenCount = 0;
    casePrice = 100;
    s_contractState = ContractState.Active;

  }

  /** 
  * @notice Need to override supportsInterface function because Contract is ERC1155 and AccessControl
  */
  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }


  // FUNCTIONS RELATED WITH THE CASE

  /**
  * @notice Change price of the box
  * @dev Only callable by the Owner
  */
  function setCasePrice(uint256 price) public onlyOwnerOrAdmin {
    casePrice = price;
    emit casePriceChanged(price);
  }



   /**
  * @notice Function used to 'open a case' and get an item
  * @dev 
  * - Should check that user owns a Ticket -> modifier
  * - Should check that msg.value is bigger than casePrice
  * - Should transfer msg.value to the contract
  * - Internally calls randomNumber() 
  * - Apply modular function for the randomNumber to be between 0 and totalSupply of items
  * - Should choose an item
  */
  function openCase() public override ownsTicket(msg.sender) supplyAvaliable contractIsActive  {  
    racksToken.transferFrom(msg.sender, address(this), casePrice);
    uint256 randomNumber = _randomNumber()  % totalSupply;
    uint256 [] memory itemList = caseLiquidity();
    uint256 totalCount = 0;
    uint256 item;

    for(uint256 i = 0 ; i < itemList.length; i++) {
      uint256 _newTotalCount = totalCount + s_maxSupply[itemList[i]] ;
      if(randomNumber > _newTotalCount) {
        totalCount = _newTotalCount;
      }else {
        item = itemList[i];
        _safeTransferFrom(address(this), msg.sender, item , 1,"");
        break;
      }
    }
    if (!isVIP(msg.sender)){ // Case opener is someone that bought a ticket
    _decreaseTicketTries(msg.sender);
    }
    emit CaseOpened(msg.sender, casePrice, item);
  }


  // FUNCTIONS RELATED TO ITEMS

  /**
  * @notice Returns maxSupply of specific item (by tokenId)
  * @dev - Getter of s_maxSupply mapping
  */
  function supplyOfItem(uint256 tokenId) public override view returns(uint256) {
    return s_maxSupply[tokenId];
  }

  /**
  * @notice Returns all the items inside the user's inventory (Could be used by the
  * user to check his inventory or to check someone else inventory by address)
  * @dev Copy users inventory in an empty array and returns it
  */
  function viewItems(address owner) public override view returns(uint256[] memory) { 
    uint256[] memory inventory = new uint256 [](s_tokenCount);
    for(uint256 i=0 ; i<inventory.length; i++) {
      inventory[i]=balanceOf(owner,i)-s_marketInventory[owner][i];
    }
    return inventory;
  }



  /**
  * @notice List a new item to the avaliable collection
  * @dev Only callable by the Owner
  */
  function listItem(uint256 itemSupply) public onlyOwnerOrAdmin {
    _mintSupply(address(this), itemSupply);
  }




  // FUNCTIONS RELATED TO THE "MARKETPLACE"

  /**
  * @notice Function used to sell an item on the marketplace
  * @dev
  * - Needs to check balanceOf item trying to be sold
  * - Needs to check if user has correctly done an Approve for the item transfer in case it is sold
  * - Needs to transfer item 
  * - Update marketItems array
  * - Emit event 
  */
  function listItemOnMarket(uint256 tokenId, uint256 price) public override {
    require(_itemStillAvailable(msg.sender, tokenId), "That item isnt available or doesnt exist.");
    require(price>0);
    s_marketInventory[msg.sender][tokenId]+=1;
    _marketItems.push(
      itemOnSale(
        tokenId,
        _marketCount,
        price,
        msg.sender,
        true
      )
    );

    _marketCount++;
    emit sellingItem(msg.sender, tokenId, price);
  }


  /**
  * @notice Function used to unlist or edit an item from marketplace
  * @dev
  * - Needs to check that user is trying to unlist an item he owns
  * - Update item's variables
  * - Emit event
  */
  function changeMarketItem(uint256 marketItemId,  uint256 newPrice) public override {
    require(_marketItems[marketItemId].itemOwner == msg.sender, "You are not the owner of this item.");
    if(newPrice==0){
      _marketItems[marketItemId].isOnSale = false;
      s_marketInventory[msg.sender][_marketItems[marketItemId].tokenId]-=1;
      emit unListedItem(msg.sender, marketItemId);
    }else{
      uint256 oldPrice = _marketItems[marketItemId].price;
      _marketItems[marketItemId].price = newPrice;
      emit itemPriceChanged(msg.sender, marketItemId, oldPrice, newPrice);

    }
  }

 

  /**
  * @notice Function used to exchange a token item for a real physical clothe.
  */
  function exchangeItem(uint256 tokenId) public override{
    require(balanceOf(msg.sender, tokenId) > 0);
    _burn(msg.sender, tokenId, 1);
    s_maxSupply[tokenId] -= 1;
    totalSupply -=1;
    emit itemExchanged(msg.sender, tokenId);
  }

  /**
  * @notice Function used to buy an item on the marketplace
  * @dev
  * - Needs to check that user is not trying to buy its own item
  * - Needs to check that item was not sold before
  * - Needs to transfer tokens from buyer to seller
  * - Needs to transfer item from seller to buyer
  * - Update sold attribute from array
  * - Emit event 
  */
  function buyItem(uint256 marketItemId) public override{
    itemOnSale memory item = _marketItems[marketItemId];
    require(msg.sender != item.itemOwner, "You can not buy an item to yourself");
    require(item.isOnSale == true, "This item is not on sale anymore.");
    require(_itemStillAvailable(item.itemOwner, item.tokenId));
    require(racksToken.allowance(msg.sender, address(this))>=item.price);
    racksToken.transferFrom(msg.sender, _marketItems[marketItemId].itemOwner, _marketItems[marketItemId].price);
    _safeTransferFrom(_marketItems[marketItemId].itemOwner, msg.sender, item.tokenId, 1 ,"");
    s_marketInventory[item.itemOwner][item.tokenId]-=1;
    address oldOwner = _marketItems[marketItemId].itemOwner;
    _marketItems[marketItemId].itemOwner = msg.sender;
    _marketItems[marketItemId].isOnSale = false;
    emit itemBought(msg.sender, oldOwner, marketItemId, _marketItems[marketItemId].price);
  }

  /**
  * @notice Function used to return items that are currently on sale
  */
  function getMarketItem(uint256 marketItemId) public override view returns(itemOnSale memory) {
    return _marketItems[marketItemId];
  }

  /**
  * @notice function used to return every item that is on sale on the MarketPlace
  */
  function getItemsOnSale() public override view returns(itemOnSale[] memory)  {
    uint256 arrayLength;
    
    for(uint256 i=0; i<_marketItems.length;i++){
      itemOnSale memory item = _marketItems[i];
      if(item.isOnSale == true && _itemStillAvailable(item.itemOwner, item.tokenId)){
        arrayLength+=1;
      }
    }
    itemOnSale[] memory items = new itemOnSale[](arrayLength);
    uint256 indexCount;
    for(uint256 i = 0; i < _marketItems.length; i++){
      itemOnSale memory  item = _marketItems[i];
      if(item.isOnSale == true && _itemStillAvailable(item.itemOwner, item.tokenId) ){
        items[indexCount]=item;
        indexCount++;
      }
    }
    return items;
  }

  // FUNCTIONS RELATED TO "TICKETS"

  /**
  * @notice This function is used for a VIP user to list 'Case Tickets' on the MarketPlace
  * @dev - Should check that user is VIP (Modifier)
  * - Check is user has had a ticket before
  *     - If so: check that is has ticket now
  *     - if not: create ticket (first ticket in live for this user)
  * - Should check that user is NOT currently selling another ticket -> Users can only sell 1 ticket at the same time
  * - Include ticket on array
  * - Increase s_ticketCount
  * - Set mapping to true
  * - Emit event
  *
  */
  function listTicket(uint256 numTries, uint256 _hours, uint256 price) public override onlyVIP {
    require(_ticketOwnership(msg.sender)==1, "User cant sell a Ticket");
    require(price>0,"Price cant be 0");
    require(_hours<=168,"Max time is 1 week.");
    require(numTries>0, "Tries cant be 0");
    s_caseTickets[msg.sender].spender = address(this);
    s_caseTickets[msg.sender].numTries = numTries;
    s_caseTickets[msg.sender].duration = _hours;
    s_caseTickets[msg.sender].price = price;
    emit newTicketOnSale(msg.sender, numTries, _hours, price);
  }

    /**
    *@notice  Returns an address´ tickets data( time, tries and onwership)

    */
  function getUserTicket(address user) public override view returns(uint256 durationLeft, uint256 triesLeft, uint256 ownerOrSpender, uint256 ticketPrice){
    uint256 ticketPrice;
    ticketPrice = _ticketOwnership(user)==4? s_caseTickets[user].price : 0;
    return (_durationLeft(user), _triesLeft(user), _ticketOwnership(user), ticketPrice);

  }

  /**
    *@notice Function to change a selling ticket conditions or even unlist it from the market
  */
  function changeMarketTicket(uint256 newTries, uint256 newHours, uint256 newPrice) public override onlyVIP {
    require(_ticketOwnership(msg.sender)==4, "User is not currently selling a Ticket");
    if(newPrice==0){
      s_caseTickets[msg.sender].spender=msg.sender;
      emit unListTicketOnSale(msg.sender);
    }

    else{
      s_caseTickets[msg.sender].numTries=newTries;
      s_caseTickets[msg.sender].duration = newHours;
      s_caseTickets[msg.sender].price = newPrice;
    emit ticketConditionsChanged(msg.sender, newTries, newHours, newPrice);

    }
  }


    /**
  * @notice This function is used to buy a caseTicket
  * @dev - Should check that user is NOT VIP -> does make sense that a VIP user buys a ticket
  * - Should check that user has a listed ticket
  * - Transfer RacksToken from buyer to seller
  * - Update mappings variables
  * - Emit event
  */

  
  function buyTicket(address owner) public override{
    require(isVIP(owner));
    caseTicket memory ticket = s_caseTickets[owner];
    require(_ticketOwnership(msg.sender)==0 , "A VIP user or a ticket owner can not buy a ticket");
    require(ticket.spender == address(this), "Ticket is not currently avaliable");
    require(racksToken.allowance(msg.sender, address(this))>=ticket.price);
    racksToken.transferFrom(msg.sender, ticket.owner, ticket.price);
    s_caseTickets[owner].timeWhenSold = block.timestamp;
    s_caseTickets[owner].spender = msg.sender;
    emit ticketBought(ticket.owner, msg.sender, ticket.price);
  }

  /** @notice Function used to claim Ticket back when duration is over
  * @dev - Check that claimer is lending a Ticket
  * - Check that duration of the Ticket is over -> block.timestamp is in seconds and duration in hours 
  * -> transform duration into seconds 
  * - Update mappings
  * - Emit event
  */


  function claimTicketBack() public override onlyVIP {
    require(_ticketOwnership(msg.sender)==3);
    require(_durationLeft(msg.sender)==0 || _triesLeft(msg.sender)==0 );
    address borrower = s_caseTickets[msg.sender].spender;
    s_caseTickets[msg.sender].spender = s_caseTickets[msg.sender].owner;
    emit ticketClaimedBack(borrower, msg.sender);
  }
  

  /**
  * @notice Function used to return every ticket that are currently on sale
  */
   function getTicketsOnSale() public override view returns(caseTicket[] memory) {
    uint256 arrayLength;
    
    for(uint256 i=0; i<s_racksMembers.length;i++){
      caseTicket memory ticket = s_caseTickets[s_racksMembers[i]];
      if(ticket.spender==address(this) && isVIP(ticket.owner)){
        arrayLength+=1;
      }
    }
    caseTicket[] memory tickets = new caseTicket[](arrayLength);
    uint256 indexCount;
    for(uint256 i = 0; i < s_racksMembers.length; i++){
      caseTicket memory ticket = s_caseTickets[s_racksMembers[i]];
      if(ticket.spender==address(this) && isVIP(ticket.owner)){
        tickets[indexCount]=ticket;
        indexCount++;
      }
    }
    return tickets;
  }
  


  
 
  // FUNCTIONS RELATED TO "USERS"
  /**
  * @notice Check if user is RacksMembers and owns at least 1 MrCrypto and is a Racks member at the same time
  * @dev - Require users MrCrypro's balance is > '
  * - Require that RacksMembers user's attribute is true
  */
  function isVIP(address user) public override view returns(bool) {
    if((MR_CRYPTO.balanceOf(user)>0) && (s_gotRacksMembers[user])) {
      return true;
    } else{
      return false;
    } 
  }

 

  /**
  * @notice Set RacksMember attribute as true for a user that is Member
  * @dev Only callable by the Owner
  * Check that user was not already racksMember
  * - If so: do nothing
  * - If not: check if user owns MrCrypto
  *      - If so: set racksMember and give Ticket
  *      - If not: set racksMember
  * 
  */
  function setSingleRacksMember(address user) public onlyOwnerOrAdmin {
    if(s_gotRacksMembers[user] == false) { // Case user is new RacksMember 
      if((MR_CRYPTO.balanceOf(user)>0)) { //Case user is new and owns MrCrypto -> set member + ticket
          s_gotRacksMembers[user] = true;
          s_racksMembers.push(user);
          s_caseTickets[user].owner=user;
          s_caseTickets[user].spender=user;
      } else{ // Case user is new and not owns MrCrypto -> just set member
          s_gotRacksMembers[user] = true;
      }
    } 
  }

    /**
  * @notice Set RacksMember attribute as true for a list of users that are Members (array)
  * @dev Only callable by the Owner
  * Require comented because maybe owner or admin are trying to set as true some address that was already set as true
  */
  function setListRacksMembers(address[] memory users) public onlyOwnerOrAdmin {
    for (uint256 i = 0; i < users.length; i++) {
      if(s_gotRacksMembers[users[i]] == false) { // Case user is new RacksMember 
        if((MR_CRYPTO.balanceOf(users[i]) > 0)) { //Case user is new and owns MrCrypto -> set member + ticket
          s_gotRacksMembers[users[i]] = true;
          s_caseTickets[users[i]].owner=users[i];
          s_caseTickets[users[i]].spender=users[i];
          
        } else{ // Case user is new and not owns MrCrypto -> just set member
          s_gotRacksMembers[users[i]] = true;
      }
    } 
    }
  }

  /**
    * @notice Returns all the VIP users
   */
  function VIPList() public override view returns(address [] memory){
    uint256 arrayLength;
    for(uint256 i =0; i< s_racksMembers.length; i++){
      if(isVIP(s_racksMembers[i])){
        arrayLength ++;
      }
    }
    address [] memory members = new address [](arrayLength);
    uint256 indexCount;
    for(uint256 j =0; j< s_racksMembers.length; j++){
      if(isVIP(s_racksMembers[j])){
        members[indexCount]=s_racksMembers[j];
        indexCount+=1;
      }
    }
    return members;
  }
  /**
  * @notice Set RacksMember attribute as false for a user that was Racks Member before but it is not now
  * @dev Only callable by the Owner
  * Require comented because maybe owner or admin are trying to set as false some address that was already set as false
  */
  function removeSingleRacksMember(address user) public onlyOwnerOrAdmin {
    //require(s_gotRacksMembers[user], "User is already not RacksMember");
    delete s_gotRacksMembers[user];
    delete s_caseTickets[user];
  }

  /**
  * @notice Set RacksMember attribute as false for a list of users that are Members (array)
  * @dev Only callable by the Owner
  * Require comented because maybe owner or admin are trying to set as false some address that was already set as false
  */
  function removeListRacksMembers(address[] memory users) public onlyOwnerOrAdmin {
    delete s_racksMembers;
    for (uint256 i = 0; i < users.length; i++) {
      //require(s_gotRacksMembers[users[i]], "User is already not RacksMember");
      delete s_gotRacksMembers[users[i]];
      delete s_caseTickets[users[i]];
    
    }
  }

  /**
  * @notice Set new Admin
  * @dev Only callable by the Owner
  */
  function setAdmin(address _newAdmin) public onlyOwner {
    _setupRole(ADMIN_ROLE, _newAdmin);
  }

  // FUNCTIONS RELATED WITH THE CONTRACT

  /**
  * @notice Change contract state from Active to Inactive and viceversa
  * @dev Only callable by the Owner or an admin
  */
  function flipContractState() public onlyOwnerOrAdmin {
    if (s_contractState == ContractState.Active) {
      s_contractState = ContractState.Inactive;
    }else {
      s_contractState = ContractState.Active;
    }
  }

  // FUNCTIONS RELATED TO ERC1155 TOKENS

  /**
  * @notice Used to return token URI by inserting tokenID
  * @dev - returns information stored in s_uris mapping
  * - Any user can check this information
  */
  function uri(uint256 tokenId) override(ERC1155, IRacksItems) public view returns (string memory) {
    return(s_uris[tokenId]);
  }

  /**
  * @notice Used to set tokenURI to specific item 
  * @dev - Only Owner or Admins can call this function
  * - Need to specify:
  *  - tokenId: specific item you want to set its uri
  *  - uri: uri wanted to be set
  */
  function setTokenUri(uint256 tokenId, string memory _uri) public onlyOwnerOrAdmin {
      require(bytes(s_uris[tokenId]).length == 0, "Can not set uri twice"); 
      s_uris[tokenId] = _uri; 
  }

  
  // FUNCTIONS RELATED TO FUNDS
  
  /**
  * @notice Used to withdraw specific amount of funds
  * @dev 
  * - Only owner is able to call this function
  * - Should check that there are avaliable funds to withdraw
  * - Should specify the wallet address you want to transfer the funds to
  * - Should specify the amount of funds you want to transfer
  */
  function withdrawFunds(address wallet, uint256 amount) public onlyOwner {
    require(racksToken.balanceOf(address(this)) > 0, "No funds to withdraw");
    racksToken.transfer(wallet, amount);
  }


  /**
    *@notice Returns all the items the case can drop
   */
  function caseLiquidity() public view returns(uint256[] memory){
    uint256 arrayLength;
    for(uint256 i=0; i< s_tokenCount; i++){
      if(balanceOf(address(this), i)>0 ){
        arrayLength++;
      }
    }

    uint256 [] memory items = new uint256[](arrayLength);
    uint256 indexCount;
    for(uint256 j=0; j< s_tokenCount; j++){
      if(balanceOf(address(this), j)>0 ){
        items[indexCount]=j;
        indexCount++;

      }
    }

    return items;


  }
 



  /*
  																									   .         .
  8 888888888o.            .8.           ,o888888o.    8 8888     ,88'   d888888o.                      ,8.       ,8.                   .8.          8 8888888888    8 8888          .8.
  8 8888    `88.          .888.         8888     `88.  8 8888    ,88'  .`8888:' `88.                   ,888.     ,888.                 .888.         8 8888          8 8888         .888.
  8 8888     `88         :88888.     ,8 8888       `8. 8 8888   ,88'   8.`8888.   Y8                  .`8888.   .`8888.               :88888.        8 8888          8 8888        :88888.
  8 8888     ,88        . `88888.    88 8888           8 8888  ,88'    `8.`8888.                     ,8.`8888. ,8.`8888.             . `88888.       8 8888          8 8888       . `88888.
  8 8888.   ,88'       .8. `88888.   88 8888           8 8888 ,88'      `8.`8888.                   ,8'8.`8888,8^8.`8888.           .8. `88888.      8 888888888888  8 8888      .8. `88888.
  8 888888888P'       .8`8. `88888.  88 8888           8 8888 88'        `8.`8888.                 ,8' `8.`8888' `8.`8888.         .8`8. `88888.     8 8888          8 8888     .8`8. `88888.
  8 8888`8b          .8' `8. `88888. 88 8888           8 888888<          `8.`8888.               ,8'   `8.`88'   `8.`8888.       .8' `8. `88888.    8 8888          8 8888    .8' `8. `88888.
  8 8888 `8b.       .8'   `8. `88888.`8 8888       .8' 8 8888 `Y8.    8b   `8.`8888.             ,8'     `8.`'     `8.`8888.     .8'   `8. `88888.   8 8888          8 8888   .8'   `8. `88888.
  8 8888   `8b.    .888888888. `88888.  8888     ,88'  8 8888   `Y8.  `8b.  ;8.`8888            ,8'       `8        `8.`8888.   .888888888. `88888.  8 8888          8 8888  .888888888. `88888.
  8 8888     `88. .8'       `8. `88888.  `8888888P'    8 8888     `Y8. `Y8888P ,88P'           ,8'         `         `8.`8888. .8'       `8. `88888. 8 8888          8 8888 .8'       `8. `88888.
  */



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
      totalSupply += amount;
      s_tokenCount += 1;
  }

  /**
  * @notice Function used to set maxSupply of each item
  */
  function _setMaxSupply(uint256 tokenId, uint256 amount) internal {
      s_maxSupply[tokenId] = amount;
  }

  /**
    *@notice Assert thath a item is still owned and approved by its owner
  */

  function _itemStillAvailable(address owner, uint256 tokenId) internal view returns(bool){
    if(balanceOf(owner, tokenId)>0 ){
      return true;
    }else{
      return false;
    }
  }
 /**
  *@notice Check if someone has a tickket 
 */
  function _ownsTicket(address user) internal view returns(bool){
      if((_ticketOwnership(user)==1 && isVIP(user) )|| (_ticketOwnership(user)==2 && _durationLeft(user)>0 && _triesLeft(user)>0 )){
        return true;
      }else{
        return false;
      }
  }
  /**
    *@notice Checks if someone is owning, selling, borrowing or lending a ticket, returns 0 else
  */
    function _ticketOwnership(address user) internal view returns(uint256){//1 for owner, 2 for borrower, 3 for lending, 4 for seller, 0 else
 
     uint256 ownerOrSpender=0;

     for(uint256 i=0; i<s_racksMembers.length; i++){
       if(s_caseTickets[s_racksMembers[i]].owner==user && s_caseTickets[s_racksMembers[i]].spender==user && isVIP(user)){
         ownerOrSpender=1; 
        break;
       }
       else if(s_caseTickets[s_racksMembers[i]].owner!=user &&  s_caseTickets[s_racksMembers[i]].spender==user ){
         ownerOrSpender=2;
         break;
       }else if(s_caseTickets[s_racksMembers[i]].owner==user && s_caseTickets[s_racksMembers[i]].spender!=address(this) && s_caseTickets[s_racksMembers[i]].spender!=user){
         ownerOrSpender=3;
         break;
       }else if(s_caseTickets[s_racksMembers[i]].owner==user && s_caseTickets[s_racksMembers[i]].spender==address(this)){
         ownerOrSpender=4;
         break;
       }

     }
      return ownerOrSpender;
  }
  
  
  /**
    *@notice Returns duration left of a ticket
    *If the user isn't spending a ticket then returns 0
    *If ticket's use time is over returns 0
  */
  function _durationLeft(address user) internal view returns(uint256){
     uint256 durationLeft=0;
    if(_ticketOwnership(user)==2 || _ticketOwnership(user)==3 || _ticketOwnership(user)==4){
      for(uint256 i=0; i< s_racksMembers.length; i++){

        if(s_caseTickets[s_racksMembers[i]].owner == user || s_caseTickets[s_racksMembers[i]].spender == user){

         uint256 duration = s_caseTickets[s_racksMembers[i]].duration * 1 hours;
         bool over = block.timestamp >  s_caseTickets[s_racksMembers[i]].timeWhenSold + duration ? true : false;
    
         if(!over){
           durationLeft = duration-((block.timestamp -  s_caseTickets[s_racksMembers[i]].timeWhenSold))/1 hours; //return hurs left multiplied by 1000 so we can reach decimals
         }
         break;

        }


       }
     }
      return durationLeft;
  }

  /**
     *@notice Returns tries left of a ticket
     *If the user isn't spending a ticket returns 0
     *If the time is over returns 0

  */
  function _triesLeft(address user) internal view returns (uint256){
     uint256 triesLeft=0;
      if(_ticketOwnership(user)==2 || _ticketOwnership(user)==3 || _ticketOwnership(user)==4){
        for(uint256 i=0; i<s_racksMembers.length; i++){
          
        if(s_caseTickets[s_racksMembers[i]].owner == user || s_caseTickets[s_racksMembers[i]].spender == user){
         uint256 duration = s_caseTickets[s_racksMembers[i]].duration * 1 hours;
         bool over = block.timestamp >  s_caseTickets[s_racksMembers[i]].timeWhenSold + duration ? true : false;
         if(!over){
           triesLeft =  s_caseTickets[s_racksMembers[i]].numTries;
          }
        break;
         }
       }


     }
      return triesLeft;
  }
  /**
  * @notice Used to get an actually Random Number -> to pick an item when openning a case
  * @dev Uses Chainlink VRF -> call requestRandomWords method by using o_vrfCoordinator object
  * set as internal because is going to be called only when a case is opened
  */
  function _randomNumber() internal returns(uint256) {
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

    /** @notice Function used to decrease Ticket tries avaliables
  * @dev - Check if used trie was last one
  *        - If not: just decrease numTries
  *        - If so: decrease numTries, update Avaliability and mappings
  */
 function _decreaseTicketTries(address user) internal {
    for (uint256 i = 0; i < s_racksMembers.length; i++) {
        if (s_caseTickets[s_racksMembers[i]].spender== user) {
            if(s_caseTickets[s_racksMembers[i]].numTries != 1) { // Case it was not the last trie avaliable
                s_caseTickets[s_racksMembers[i]].numTries--;
                break;
            }else { // it was his last trie avaliable
                s_caseTickets[s_racksMembers[i]].numTries--;
                s_caseTickets[s_racksMembers[i]].spender= s_caseTickets[s_racksMembers[i]].owner;
                break;
            
            }
         
        }   


    } 
  }

   /**
  * @notice Check that item exists (by tokenId)
  */
  function _itemExists(uint256 tokenId) internal view returns (bool) {
    require(s_maxSupply[tokenId] > 0);
    return true;
  }

   /**
  * @notice Check if user is owner of the Contract or has admin role
  * @dev Only callable by the Owner
  */
  function _isOwnerOrAdmin(address user) internal view returns (bool) {
    require(_owner == user || hasRole(ADMIN_ROLE, user));
    return true;
  }
}