// SPDX-License-Identifier: MIT
// 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
// 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f


pragma solidity ^0.8.0;

import "./IRacksItems.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol"; 
import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155.sol"; 
import "../node_modules/@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol"; 
import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 
import "../node_modules/@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol"; 

contract RacksItemsv3 is IRacksItems, ERC1155, ERC1155Holder, AccessControl, VRFConsumerBaseV2 { 
   
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
    uint256 private s_maxTotalSupply;
    uint256 private s_tokenCount;
    uint256 private _marketCount;
    uint256 private s_ticketCount;
    uint256 private casePrice; 
    ContractState private s_contractState;
    itemOnSale[] private _marketItems;
    caseTicket[] private _tickets;

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
    mapping(address => bool) private s_isSellingTicket;
    mapping(address => bool) private s_hasTicket; 
    mapping(address => bool) private s_hadTicket;
    mapping(address => bool) private s_ticketIsLended;
    mapping (address => mapping(uint256=> uint256)) s_marketInventory;
    mapping(address => uint256) s_lastTicket;

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
    require(isVip(msg.sender), "User does not owns a MrCrypto");
        _;
    }

    /**  @notice Check that user is owns at least 1 ticket for opening case (used in case user
    * does not own a MrCrypto and buys a ticket from another user)
    */
    modifier ownsTicket() {
    require(s_hasTicket[msg.sender], "User does not owns a Ticket for openning the case.");
    _;
    }

    /**  @notice Check that there is at least 1 item avaliable so the user can open a case for example
    */
    modifier supplyAvaliable() {
    require(s_maxTotalSupply > 0, "There are no items avaliable");
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
    s_ticketCount = 0;
    casePrice = 1;
    s_contractState = ContractState.Active;

    }

    /** 
    * @notice Need to override supportsInterface function because Contract is ERC1155 and AccessControl
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
    }


    //////////////////////
    //  Case Functions // 
    /////////////////////

    /**
    * @notice Change price of the box
    * @dev Only callable by the Owner
    */
    function setCasePrice(uint256 price) public onlyOwnerOrAdmin {
    casePrice = price;
    emit casePriceChanged(price);
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
    function openCase() public override supplyAvaliable contractIsActive  {  
    if (MR_CRYPTO.balanceOf(msg.sender) < 1) {
        require(s_hasTicket[msg.sender], "User does not owns a Ticket for openning the case.");
    }
    uint caseSupply;
    racksToken.transferFrom(msg.sender, address(this), casePrice);
    uint256 [] memory itemList = caseLiquidity();
    for(uint i =0 ;i<itemList.length; i++){
      caseSupply+=s_maxSupply[itemList[i]];
    }
    uint256 randomNumber = _randomNumber()  % caseSupply;
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
    if (!isVip(msg.sender)){ // Case opener is someone that bought a ticket
    decreaseTicketTries(msg.sender);
    }
    emit CaseOpened(msg.sender, casePrice, item);
    }

    /**
    * @notice Returns all the items the case can drop
    */
    function caseLiquidity() public view override returns(uint256[] memory){
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


    //////////////////////
    //  Item Functions // 
    /////////////////////

    /**
    * @notice Returns maxSupply of specific item (by tokenId)
    * @dev - Getter of s_maxSupply mapping
    */
    function supplyOfItem(uint256 tokenId) public view override returns(uint) {
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
    * @notice Returns all the items inside the user's inventory without the ones on Market Sale(Could be used by the
    * user to check his inventory or to check someone else inventory by address)
    * @dev Copy users inventory in an empty array and returns it
    */
    function viewItems(address owner) public view override returns(uint256[] memory) { 
    uint256[] memory inventory = new uint [](s_tokenCount);
    for(uint256 i=0 ; i < inventory.length; i++) {
        inventory[i] = balanceOf(owner,i) - s_marketInventory[owner][i];
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


    ////////////////////////////
    //  Marketplace Functions // 
    ///////////////////////////

    /**
    * @notice Function used to sell an item on the marketplace
    * @dev
    * - Needs to check balanceOf item trying to be sold
    * - Needs to check if user has correctly done an Approve for the item transfer in case it is sold
    * - Needs to transfer item 
    * - Update s_marketInventory
    * - Update marketItems array
    * - Emit event 
    */
    function listItemOnMarket(uint256 marketItemId, uint256 price) public override {
    require(balanceOf(msg.sender, marketItemId) > 0, "Item not found.");
    require(price > 0, "Price must be greater than 0");
    s_marketInventory[msg.sender][marketItemId] += 1;
    _marketItems.push(
        itemOnSale(
        marketItemId,
        _marketCount,
        price,
        msg.sender,
        true
        )
    );
    _marketCount++;
    emit sellingItem(msg.sender, marketItemId, price);
    }

    /**
    * @notice Function used to unlist an item from marketplace
    * @dev
    * - Needs to check that user is trying to unlist an item he owns
    * - Update marketInventory
    * - Update item's sold variable
    * - Emit event
    */
    function unListItem(uint256 marketItemId) public override {
    require(_marketItems[marketItemId].itemOwner == msg.sender, "You are not the owner of this item.");
    s_marketInventory[msg.sender][_marketItems[marketItemId].tokenId] -= 1;
    _marketItems[marketItemId].isOnSale = false;
    emit unListedItem(msg.sender, marketItemId);
    }

    /**
    * @notice Function used to change price from item listed 
    * @dev
    * - Needs to check that user is trying to unlist an item he owns
    * - Needs to update price status
    * - Emit event
    */
    function changeItemPrice(uint256 marketItemId, uint256 newPrice) public override {
    require(_marketItems[marketItemId].itemOwner == msg.sender, "You are not the owner of this item.");
    uint256 oldPrice = _marketItems[marketItemId].price;
    _marketItems[marketItemId].price = newPrice;
    emit itemPriceChanged(msg.sender, marketItemId, oldPrice, newPrice);
    }

    /**
    * @notice Function used to exchange a token item for a real physical clothe.
    */
    function exchangeItem(uint256 tokenId) public override {
    require(balanceOf(msg.sender, tokenId) > 0);
    _burn(msg.sender, tokenId, 1);
    s_maxSupply[tokenId] -= 1;
    s_maxTotalSupply -=1;
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
    function buyItem(uint256 marketItemId) public override {
    itemOnSale memory item = _marketItems[marketItemId];
    require(msg.sender != _marketItems[marketItemId].itemOwner, "You can not buy an item to yourself");
    require(_marketItems[marketItemId].isOnSale == true, "This item is not on sale anymore.");
    require(_itemStillAvailable(item.itemOwner, item.tokenId), "Item does not exist.");
    require(racksToken.allowance(msg.sender, address(this)) >= item.price, "Insufficient ERC20 allowance");
    racksToken.transferFrom(msg.sender, _marketItems[marketItemId].itemOwner, _marketItems[marketItemId].price);
    _safeTransferFrom(_marketItems[marketItemId].itemOwner, msg.sender, _marketItems[marketItemId].tokenId, 1 ,"");
    s_marketInventory[item.itemOwner][item.tokenId]-=1;
    address oldOwner = _marketItems[marketItemId].itemOwner;
    _marketItems[marketItemId].itemOwner = msg.sender;
    _marketItems[marketItemId].isOnSale = false;
    emit itemBought(msg.sender, oldOwner, marketItemId, _marketItems[marketItemId].price);
    }

    /**
    * @notice Function used to return items that are currently on sale
    */
    function getMarketItem(uint marketItemId) public view override returns(itemOnSale memory){
    return _marketItems[marketItemId];
    }

    /**
    * @notice function used to return every item that is on sale on the MarketPlace
    */
    function getItemsOnSale() public view override returns(itemOnSale[] memory) {
    uint arrayLength;

    for(uint i=0; i<_marketItems.length;i++){
        itemOnSale memory item = _marketItems[i];
        if(item.isOnSale == true && _itemStillAvailable(item.itemOwner, item.tokenId)){
        arrayLength+=1;
        }
    }
    itemOnSale[] memory items = new itemOnSale[](arrayLength);
    uint indexCount;
    for(uint256 i = 0; i < _marketItems.length; i++){
        itemOnSale memory  item = _marketItems[i];
        if(item.isOnSale == true  && _itemStillAvailable(item.itemOwner, item.tokenId)){
        items[indexCount]=item;
        indexCount++;
        }
    }
    return items;
    }

    //////////////////////
    //  Ticket Functions // 
    /////////////////////

    /**
    * @notice This function is used for a VIP user to list 'Case Tickets' on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
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
    function listTicket(uint256 numTries, uint256 _hours, uint256 price) public override onlyVIP contractIsActive  {
    require(!s_isSellingTicket[msg.sender], "User is already currently selling a Ticket");
    if(s_hadTicket[msg.sender]) {
    require(s_hasTicket[msg.sender], "User has not ticket avaliable");
    }
        _tickets.push(
        caseTicket(
        s_ticketCount,
        numTries,
        _hours,
        price,
        msg.sender,
        0,
        true
        ));
        s_lastTicket[msg.sender] = s_ticketCount;
        s_ticketCount++;
        s_isSellingTicket[msg.sender] = true;
        s_hadTicket[msg.sender] = true;
        s_hasTicket[msg.sender] = false;
        emit newTicketOnSale(msg.sender, numTries, _hours, price);
    }

    /**
    * @notice This function is used for a VIP user to unlist 'Case Tickets' on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function unListTicket() public override onlyVIP contractIsActive  {
    uint ticketId = s_lastTicket[msg.sender];
    require(s_isSellingTicket[msg.sender], "User is not currently selling a Ticket");
    require(_tickets[ticketId].owner == msg.sender, "User is not owner of this ticket");
    _tickets[ticketId].isAvaliable = false;
    s_isSellingTicket[msg.sender] = false;
    s_hasTicket[msg.sender] = true;
    emit unListTicketOnSale(msg.sender);
    }

    /**
    * @notice This function is used for a VIP user to change 'Case Tickets' price and tries on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function changeTicketConditions(uint256 newTries, uint256 newHours, uint256 newPrice) public override onlyVIP contractIsActive {
    uint ticketId = s_lastTicket[msg.sender];
    require(s_isSellingTicket[msg.sender], "User is not currently selling a Ticket");
    require(_tickets[ticketId].owner == msg.sender, "User is not owner of this ticket");
    _tickets[ticketId].price = newPrice;
    _tickets[ticketId].duration = newHours;
    _tickets[ticketId].numTries = newTries;
    emit ticketConditionsChanged(msg.sender, newTries, newHours, newPrice);
    }

    /**
    * @notice This function is used to buy a caseTicket
    * @dev - Should check that user is NOT Vip -> does make sense that a VIP user buys a ticket
    * - Should check that user has a listed ticket
    * - Transfer RacksToken from buyer to seller
    * - Update mappings variables
    * - Emit event
    */
    function buyTicket(uint256 ticketId) public override contractIsActive {
    require(!isVip(msg.sender), "A VIP user can not buy a ticket");
    require(_tickets[ticketId].owner != msg.sender, "You can not buy a ticket to your self");
    require(_tickets[ticketId].isAvaliable == true, "Ticket is not currently avaliable");
    address oldOwner = _tickets[ticketId].owner;
    racksToken.transferFrom(msg.sender, _tickets[ticketId].owner, _tickets[ticketId].price);
    _tickets[ticketId].timeWhenSold = block.timestamp;
    s_hasTicket[_tickets[ticketId].owner] = false;
    s_isSellingTicket[_tickets[ticketId].owner] = false;
    s_ticketIsLended[_tickets[ticketId].owner] = true;
    s_hasTicket[msg.sender] = true;
    _tickets[ticketId].owner = msg.sender;
    _tickets[ticketId].isAvaliable = false;
    s_lastTicket[msg.sender] = ticketId;
    emit ticketBought(ticketId, oldOwner, msg.sender, _tickets[ticketId].price);
    }

    /** @notice Function used to claim Ticket back when duration is over
    * @dev - Check that claimer is lending a Ticket
    * - Check that duration of the Ticket is over -> block.timestamp is in seconds and duration in hours 
    * -> transform duration into seconds 
    * - Update mappings
    * - Emit event
    */
    function claimTicketBack() public override onlyVIP {
    uint ticketId = s_lastTicket[msg.sender];
    require(s_ticketIsLended[msg.sender], "User did not sell any Ticket");
    require((_tickets[ticketId].numTries == 0) || (((block.timestamp - _tickets[ticketId].timeWhenSold)/60) == (_tickets[ticketId].duration * 60)), "Duration of the Ticket or numTries is still avaliable");
    address oldOwner = _tickets[ticketId].owner;
    s_hasTicket[_tickets[ticketId].owner] = false;
    s_hasTicket[msg.sender] = true;
    s_ticketIsLended[msg.sender] = false;
    _tickets[ticketId].owner = msg.sender;
    _tickets[ticketId].isAvaliable = true;
    s_hasTicket[_tickets[ticketId].owner] = true;
    emit ticketClaimedBack(oldOwner, msg.sender);
    }

    /** @notice Function used to decrease Ticket tries avaliables
    * @dev - Check if used trie was last one
    *        - If not: just decrease numTries
    *        - If so: decrease numTries, update Avaliability and mappings
    */
    function decreaseTicketTries(address user) internal {
    for (uint256 i = 0; i < _tickets.length; i++) {
        if (_tickets[i].owner == user) {
            if(_tickets[i].numTries != 1) { // Case it was not the last trie avaliable
                _tickets[i].numTries--;
            }else { // it was his last trie avaliable
                _tickets[i].numTries--;
                _tickets[i].isAvaliable = false;
                s_hasTicket[user] = false;
            }
        }       
    } 
    }

    /**
    * @notice Function used to return ticket that are currently on sale
    */
    function getMarketTicket(uint256 ticketId) public view override returns(caseTicket memory) {
    return _tickets[ticketId];
    }

    /**
    * @notice Function used to return every ticket that are currently on sale
    */
    function getTicketsOnSale() public view override returns(caseTicket[] memory) {
    uint arrayLength;

    for(uint i=0; i<_tickets.length;i++){
        caseTicket memory ticket = _tickets[i];
        if(ticket.isAvaliable==true){
        arrayLength+=1;
        }
    }
    caseTicket[] memory tickets = new caseTicket[](arrayLength);
    uint indexCount;
    for(uint256 i = 0; i < _tickets.length; i++){
        caseTicket memory ticket = _tickets[i];
        if(ticket.isAvaliable==true){
        tickets[indexCount]=ticket;
        indexCount++;
        }
    }
    return tickets;
    }

    /**
    * @notice Function used to check if an item is still owned and approved by its owner
    */
    function _itemStillAvailable(address owner, uint256 tokenId) internal view returns(bool){
    if(balanceOf(owner, tokenId) > 0){
        return true;
    }else{
        return false;
    }
    }

    /**
    * @notice Function used to view how much time is left for lended Ticket
    * @dev This function returns 3 parameters
    * - address: ticketOwner
    * - uint256: timeLeft 
    * - bool: false if numTries == 0
    *         true if numTries > 0
    */
    function getTicketDurationLeft(uint256 ticketId) public view override returns (address, uint256, bool) {
    require(_tickets[ticketId].timeWhenSold > 0, "Ticket is not sold yet.");
    uint256 timeLeft;
    if ((_tickets[ticketId].numTries == 0)) {
        if((((block.timestamp - _tickets[ticketId].timeWhenSold)/60) == (_tickets[ticketId].duration * 60))) {
        timeLeft = 0;
        return (_tickets[ticketId].owner, timeLeft, false);
        }else {
        timeLeft = (_tickets[ticketId].duration * 60) - ((block.timestamp - _tickets[ticketId].timeWhenSold)/60);
        return (_tickets[ticketId].owner, timeLeft, false);
        } 
    } else {
        if((((block.timestamp - _tickets[ticketId].timeWhenSold)/60) == (_tickets[ticketId].duration * 60))) {
        timeLeft = 0;
        return (_tickets[ticketId].owner, timeLeft, true);
        }else {
        timeLeft = (_tickets[ticketId].duration * 60) - ((block.timestamp - _tickets[ticketId].timeWhenSold)/60);
        return (_tickets[ticketId].owner, timeLeft, true);
        } 
    }
    }


    /**
    *@notice  Returns an address tickets data(time, tries , onwership and price)
    */
    function getUserTicket(address user) public view override returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice) {
    if(_ticketOwnership(user)==1 || _ticketOwnership(user)==0){
      return(0,0,_ticketOwnership(user), 0);
    }else{
    uint256 ticketId = s_lastTicket[user];
    (,uint256 timeLeft,) = getTicketDurationLeft(ticketId);
    return (timeLeft, _tickets[ticketId].numTries, _ticketOwnership(user), _tickets[ticketId].price);
    }
    }


    //////////////////////
    //  User Functions // 
    /////////////////////
    function _ticketOwnership(address user) internal view returns(uint ownerOrSpender){
      uint ticketOwnership;
      if (isVip(user) && !s_hadTicket[user]){
        ticketOwnership=1;
        } else if(!isVip(user)&& s_hasTicket[user] ){
          ticketOwnership=2;
        }else if(isVip(user) && !s_isSellingTicket[user] && !s_hasTicket[user] && s_hadTicket[user] && s_ticketIsLended[user]){
          ticketOwnership=3;
        } else if (isVip(user) && s_isSellingTicket[user] && !s_hasTicket[user] && s_hadTicket[user]){
          ticketOwnership=4;
        }else{
          ticketOwnership=0;
        }
      return ticketOwnership;
    }
    /**
    * @notice Check if user owns at least 1 MrCrypto
    * @dev - Require users MrCrypro's balance is > 0
    */
    function isVip(address user) public view override returns(bool) {
    if((MR_CRYPTO.balanceOf(user) > 0)) {
        return true;
    } else{
        return false;
    } 
    }

    /**
    * @notice Check if user is owner of the Contract or has admin role
    * @dev Only callable by the Owner
    */
    function _isOwnerOrAdmin(address user) internal view returns (bool) {
    require(_owner == user || hasRole(ADMIN_ROLE, user));
    return true;
    }

    /**
    * @notice Set new Admin
    * @dev Only callable by the Owner
    */
    function setAdmin(address _newAdmin) public override onlyOwner {
    _setupRole(ADMIN_ROLE, _newAdmin);
    }

    ////////////////////////////
    //  Management Functions // 
    //////////////////////////

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

    ////////////////////////////
    //  ERC1155 Functions   // 
    //////////////////////////

    /**
    * @notice Used to return token URI by inserting tokenID
    * @dev - returns information stored in s_uris mapping
    * - Any user can check this information
    */
    function uri(uint256 tokenId) override public view returns (string memory) {
    return(s_uris[tokenId]);
    }

    /**
    * @notice Used to set tokenURI to specific item 
    * @dev - Only Owner or Admins can call this function
    * - Need to specify:
    *  - tokenId: specific item you want to set its uri
    *  - uri: uri wanted to be set
    */
    function setTokenUri(uint256 tokenId, string memory _uri) public override onlyOwnerOrAdmin {
        require(bytes(s_uris[tokenId]).length == 0, "Can not set uri twice"); 
        s_uris[tokenId] = _uri; 
    }

    ////////////////////////
    //  Funds Functions // 
    //////////////////////

    /**
    * @notice Used to withdraw specific amount of funds
    * @dev 
    * - Only owner is able to call this function
    * - Should check that there are avaliable funds to withdraw
    * - Should specify the wallet address you want to transfer the funds to
    * - Should specify the amount of funds you want to transfer
    */
    function withdrawFunds(address wallet, uint256 amount) public override onlyOwner {
    require(racksToken.balanceOf(address(this)) > 0, "No funds to withdraw");
    racksToken.transfer(wallet, amount);
    }

    /**
    * @notice Used to withdraw ALL funds
    * @dev 
    * - Only owner is able to call this function
    * - Should check that there are avaliable funds to withdraw
    * - Should specify the wallet address you want to transfer the funds to
    */
    function withdrawAllFunds(address wallet) public override onlyOwner {
    require(racksToken.balanceOf(address(this)) > 0, "No funds to withdraw");
    racksToken.transfer(wallet, racksToken.balanceOf(address(this)));
    }

    /// @notice Receive function
    receive() external payable {
    }

     //////////////
    //  Getters // 
    //////////////

    function getOwner() public view returns(address) {
        return _owner;
    }

    function getMaxTotalSupply() public view returns(uint256) {
        return s_maxTotalSupply;
    }

    function getTokenCount() public view returns(uint256) {
        return s_tokenCount;
    }

    function getMarketcount() public view returns(uint256) {
        return _marketCount;
    }

    function getTicketCount() public view returns(uint256) {
        return s_ticketCount;
    }

    function getPriceCase() public view returns(uint256) {
        return casePrice;
    }

    function getContractState() public view returns(ContractState) {
        return s_contractState;
    }

   function getItemsOnSale(uint256 itemId) public view returns(itemOnSale memory) {
        return _marketItems[itemId];
   }

    function getTicket(uint256 ticketId) public view returns(caseTicket memory) {
        return _tickets[ticketId];
    }
}