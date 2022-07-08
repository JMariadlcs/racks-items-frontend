// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ICaseOpener.sol";
import "./IRacksItems.sol";
import "./ITickets.sol";
import "@openzeppelin/contracts/access/AccessControl.sol"; 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol"; 
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol"; 
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 

contract RacksItemsv3 is IRacksItems, ERC1155, ERC1155Holder, AccessControl{ 
   
    /**
    * @notice Enum for Contract state -> to let user enter call some functions or not
    */
    enum ContractState {   
    Active,
    Inactive
    }
    //Interfaces
    ICaseOpener CASE_OPENER;
    ITickets TICKETS;

    /// @notice tokens
    IERC721Enumerable MR_CRYPTO;
    IERC20 racksToken;

    /// @notice Standard variables
    bytes32 public constant ADMIN_ROLE = 0x00;
    address private _owner;
    uint256 private s_maxTotalSupply;
    uint256 private s_tokenCount;
    uint256 private _marketCount;
    uint256 private casePrice; 
    ContractState private s_contractState;
    itemOnSale[] private _marketItems;




    /// @notice Mappings
    mapping(uint => uint) private s_maxSupply;
    mapping (uint256 => string) private s_uris; 
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
    require(isVip(msg.sender), "User does not owns a MrCrypto");
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

    constructor(address _racksTokenAddress, address _MockMrCryptoAddress) 
    ERC1155(""){
        
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
            (,,uint ownerOrSpender,)= TICKETS.getUserTicket(msg.sender);
            require(ownerOrSpender==2, "User does not own a Ticket for openning the case.");
        }

        racksToken.transferFrom(msg.sender , address(this), casePrice);
        uint item = CASE_OPENER.openCase();
        _safeTransferFrom(address(this), msg.sender, item , 1,"");

        if (!isVip(msg.sender)){ // Case opener is someone that bought a ticket
            TICKETS.decreaseTicketTries(msg.sender);
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
        TICKETS.listTicket(numTries, _hours , price, msg.sender);
        emit newTicketOnSale(msg.sender, numTries, _hours, price);
    }

    /**
    * @notice This function is used for a VIP user to unlist 'Case Tickets' on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function unListTicket() public override onlyVIP contractIsActive  {
        TICKETS.unListTicket(msg.sender);
        emit unListTicketOnSale(msg.sender);
    }

    /**
    * @notice This function is used for a VIP user to change 'Case Tickets' price and tries on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function changeTicketConditions(uint256 newTries, uint256 newHours, uint256 newPrice) public override onlyVIP contractIsActive {
        TICKETS.changeTicketConditions( newTries,  newHours,  newPrice, msg.sender);
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
        (,,uint price,address oldOwner,,) = TICKETS.getMarketTicket(ticketId);
        racksToken.transferFrom(msg.sender, oldOwner, price);  
        TICKETS.buyTicket(ticketId, msg.sender);
        emit ticketBought(ticketId, oldOwner, msg.sender, price);
    }

    /** @notice Function used to claim Ticket back when duration is over
    * @dev - Check that claimer is lending a Ticket
    * - Check that duration of the Ticket is over -> block.timestamp is in seconds and duration in hours 
    * -> transform duration into seconds 
    * - Update mappings
    * - Emit event
    */
    function claimTicketBack() public override onlyVIP {
        TICKETS.claimTicketBack(msg.sender);
        emit ticketClaimedBack( msg.sender);
    }

   

    /**
    * @notice Function used to return ticket that are currently on sale
    */
    function getMarketTicket(uint256 ticketId) public view override returns( uint256 numTries, uint256 duration, uint256 price, address owner, uint256 timeWhenSold, bool isAvaliable) {
        TICKETS.getMarketTicket(ticketId);
    }

    /**
    * @notice Function used to return every ticket that are currently on sale
    */
    function getTicketsOnSale() public view override returns(ITickets.caseTicket[] memory) {
        ITickets.caseTicket[] memory caseTickets =  TICKETS.getTicketsOnSale();
        return caseTickets;
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
        return TICKETS.getTicketDurationLeft(ticketId);
    }
    


    /**
    *@notice  Returns an address tickets data(time, tries , onwership and price)
    */
    function getUserTicket(address user) public view override returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice) {
       return TICKETS.getUserTicket(user);
    }


    //////////////////////
    //  User Functions // 
    /////////////////////
    
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


    function setInterfaces(address _caseOpenerAddress, address _ticketsAddress) public onlyOwner{
        CASE_OPENER  = ICaseOpener(_caseOpenerAddress);
        TICKETS = ITickets(_ticketsAddress);

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
  

    function getContractState() public view returns(ContractState) {
        return s_contractState;
    }

    function getCasePrice() public view returns(uint){
        return casePrice;
    }


}