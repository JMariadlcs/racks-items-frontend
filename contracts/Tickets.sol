// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ITickets.sol";
import "./IRacksItems.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 

contract Tickets is ITickets{

    IRacksItems RacksItems;
    IERC721Enumerable MR_CRYPTO;
    uint256 private s_ticketCount;
    mapping(address => mapping(address => bool)) ticketApprovals;
    mapping (address => bool) approved;
    mapping(address => bool) private s_isSellingTicket;
    mapping(address => bool) private s_hasTicket; 
    mapping(address => bool) private s_hadTicket;
    mapping(address => bool) private s_ticketIsLended;
    mapping(address => uint256) s_lastTicket;
    mapping(uint => bool) s_isLocked;
    mapping(address => uint256[]) s_locked_mrCrypto;
    caseTicket[] private _tickets;

    modifier notForUsers(){
       require(msg.sender==address(RacksItems),"This function is specially reserved for the main contract.");
       _;
    }
    constructor(address _racksItems, address _mrCrypto){
       RacksItems = IRacksItems(_racksItems);
       MR_CRYPTO = IERC721Enumerable(_mrCrypto);  
    }

    
    function _listT(address from ,uint256 numTries, uint256 _hours, uint256 price, address user) external notForUsers  override{
        if(from!=user){
            require(ticketAllowance(from, user));
        }

        require(!s_isSellingTicket[from], "User is already currently selling a Ticket");
        if(s_hadTicket[from]) {
            require(s_hasTicket[from] , "User has not ticket avaliable");
        }
        bool success = _lockMrCrypto(from);
        require(success,"Sorry, you already have a Mr Crypto on use.");
        _tickets.push(
        caseTicket(
        s_ticketCount,
        numTries,
        _hours,
        price,
        from,
        0,
        true
        ));

        s_lastTicket[from] = s_ticketCount;
        s_ticketCount++;
        s_isSellingTicket[from] = true;
        s_hadTicket[from] = true;
        s_hasTicket[from] = false;
    }

    function _unlistT(address from, address user) external notForUsers override{
        if(from!=user){
            require(ticketAllowance(from, user));
        }
        
        uint ticketId = s_lastTicket[from];
        require(s_isSellingTicket[from], "User is not currently selling a Ticket");
        require(_tickets[ticketId].owner == from, "User is not owner of this ticket");
        _tickets[ticketId].isAvaliable = false;
        s_isSellingTicket[from] = false;
        s_hasTicket[from] = true;
        _unlockMrCrypto(from);
     
    }

    function _changeT(address from , uint256 newTries, uint256 newHours, uint256 newPrice, address user) external notForUsers override{
        if(from!=user){
            require(ticketAllowance(from,user));
        }
        uint ticketId = s_lastTicket[from];
        require(s_isSellingTicket[from], "User is not currently selling a Ticket");
        require(_tickets[ticketId].owner == user, "User is not owner of this ticket");
        _tickets[ticketId].price = newPrice;
        _tickets[ticketId].duration = newHours;
        _tickets[ticketId].numTries = newTries;
     
    }

    function _buyT(uint256 ticketId, address user) external notForUsers override{

        require(RacksItems.isVip(user)==false, "A VIP user can not buy a ticket");
        require(_tickets[ticketId].owner != user, "You can not buy a ticket to your self");
        require(_tickets[ticketId].isAvaliable == true, "Ticket is not currently avaliable");    
        _tickets[ticketId].timeWhenSold = block.timestamp;
        s_hasTicket[_tickets[ticketId].owner] = false;
        s_isSellingTicket[_tickets[ticketId].owner] = false;
        s_ticketIsLended[_tickets[ticketId].owner] = true;
        s_hasTicket[user] = true;
        _tickets[ticketId].owner = msg.sender;
        _tickets[ticketId].isAvaliable = false;
        s_lastTicket[user] = ticketId;
       
    }

    /** @notice Function used to claim Ticket back when duration is over
    * @dev - Check that claimer is lending a Ticket
    * - Check that duration of the Ticket is over -> block.timestamp is in seconds and duration in hours 
    * -> transform duration into seconds 
    * - Update mappings
    * - Emit event
    */

    function _claimT(address from , address user) external notForUsers override{
        if(from!=user){
            require(ticketAllowance(from,user));
        }
        uint ticketId = s_lastTicket[from];
        require(s_ticketIsLended[from], "User did not sell any Ticket");
        require((_tickets[ticketId].numTries == 0) || (((block.timestamp - _tickets[ticketId].timeWhenSold)/60) >= (_tickets[ticketId].duration * 60)), "Duration of the Ticket or numTries is still avaliable");
        s_hasTicket[_tickets[ticketId].owner] = false;
        s_hasTicket[from] = true;
        s_ticketIsLended[from] = false;
        _unlockMrCrypto(user);
  
    }

    /** @notice Function used to decrease Ticket tries avaliables
    * @dev - Check if used trie was last one
    *        - If not: just decrease numTries
    *        - If so: decrease numTries, update Avaliability and mappings
    */

    function _decreaseT(address user) external notForUsers override {
        uint ticketId = s_lastTicket[user];
        if(_tickets[ticketId].numTries != 1) { // Case it was not the last try avaliable
            _tickets[ticketId].numTries--;
        }else { // it was his last try avaliable
            _tickets[ticketId].numTries--;
            s_hasTicket[user] = false;
        }

     }
     function getUserTicket(address user) public view override returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice) {
        if(_ticketOwnership(user)==1 || _ticketOwnership(user)==0 || _ticketOwnership(user)==4){
          return(0,0,_ticketOwnership(user), 0);
        }else{
        uint256 ticketId = s_lastTicket[user];
        uint256 timeLeft = _getTicketDurationLeft(ticketId);
        return (timeLeft, _tickets[ticketId].numTries, _ticketOwnership(user), _tickets[ticketId].price);
        }
    }

    function getMarketTicket(uint256 ticketId) public override view returns( uint256 numTries, uint256 duration, uint256 price, address owner, uint256 timeWhenSold, bool isAvaliable){
        caseTicket memory ticket = _tickets[ticketId];  
        return(
            ticket.numTries,
            ticket.duration,
            ticket.price,
            ticket.owner,
            ticket.timeWhenSold,
            ticket.isAvaliable
        );

        
    }

    //////////////////////
    //  User Functions // 
    /////////////////////

    /**
    *Returns the users` ticket ownership:
        -1 if is VIP and owns a ticket
        -2 if is NOT VIP and owns a ticket
        -3 if is VIP and ticket is lended
        -4 if is VIP and currently selling a ticket
        -0 else
    
    */

    function _ticketOwnership(address user) internal view returns(uint ownerOrSpender){
      require(msg.sender==address(RacksItems), "This function is specially reserved for the main contract.");
      uint ticketOwnership;
      if (RacksItems.isVip(user) && !s_isSellingTicket[user] &&  !s_ticketIsLended[user]){
        ticketOwnership=1;
        } else if(!RacksItems.isVip(user) && s_hasTicket[user] ){
          ticketOwnership=2;
        }else if(RacksItems.isVip(user) && !s_isSellingTicket[user] && !s_hasTicket[user] && s_hadTicket[user] && s_ticketIsLended[user]){
          ticketOwnership=3;
        } else if (RacksItems.isVip(user) && s_isSellingTicket[user] && !s_hasTicket[user] && s_hadTicket[user]){
          ticketOwnership=4;
        }else{
          ticketOwnership=0;
        }
      return ticketOwnership;
    }


   


    function _approveT(address owner, address spender, bool permission) external notForUsers override {
      ticketApprovals[owner][spender]=permission;
    }

    function ticketAllowance(address owner, address spender) public override view returns(bool){
      return ticketApprovals[owner][spender];
    }

    function isApproved(address user) public override view returns(bool){
      return approved[user];
    }

    
    function getTicketsOnSale() public view override returns(caseTicket[] memory) {
        require(msg.sender==address(RacksItems), "This function is specially reserved for the main contract.");
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

     function _getTicketDurationLeft(uint256 ticketId) internal view  returns (uint256) {
            uint256 timeLeft;
            if((((block.timestamp - _tickets[ticketId].timeWhenSold)/60) >= (_tickets[ticketId].duration * 60))) {
              timeLeft = 0;
              return (timeLeft);
            }else {
              timeLeft = (_tickets[ticketId].duration * 60) - ((block.timestamp - _tickets[ticketId].timeWhenSold)/60);
              return (timeLeft);
            } 
            
    }
     //////////////////////////
    //  MR Crypto functions // 
    /////////////////////////

    /**
    *@notice This functions are meant to prevent a security issue.
    *Thank to this functions each Mr Crypto can only have one ticket at every moment, so even if someone sends it to other wallet wont be able to use a ticket till is unlocked
    */


    /**
    *@notice Returns the IDs of all the Mr Cryptos owned by a user
    */
    function _mrCryproWallet(address user) internal  view returns (uint256[] memory){

        uint256 ownerTokenCount = MR_CRYPTO.balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; ++i) {
            tokenIds[i] = MR_CRYPTO.tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }

    /**
    *@dev This functions saves the id of the mr crypto used to sell a ticket in a mapping
    */
    function _lockMrCrypto(address user) internal returns (bool){
        bool success;
        uint [] memory wallet = _mrCryproWallet(user);
        for(uint i=0; i<wallet.length; i++){
            if(!s_isLocked[wallet[i]]){
                s_locked_mrCrypto[user].push(wallet[i]);
                success = true;
                break;
            }
        }
        return success;
        
    }
    /**
    *@dev After a ticket live is over and the owner gets his ticket back his MrCrypto will be able to sell tickets again using the mapping
    */
    function _unlockMrCrypto(address user) internal {
        uint [] memory locked = s_locked_mrCrypto[user];
        for(uint i=0; i<locked.length; i++){
            if(locked[i]!=0){
                delete s_locked_mrCrypto[user][i];
                s_isLocked[i]=false;
                break;
            }
        }
    }

    //Returns current ticket count.
    function getTicketCount() public override view returns(uint256) {
      return s_ticketCount;
    }



}