pragma solidity ^0.8.0;
import "./ITickets.sol";
import "./IRacksItems.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 

    contract Tickets is ITickets{
        IRacksItems RacksItems;
        IERC721Enumerable MR_CRYPTO;
        uint256 private s_ticketCount;
        mapping(address => bool) private s_isSellingTicket;
        mapping(address => bool) private s_hasTicket; 
        mapping(address => bool) private s_hadTicket;
        mapping(address => bool) private s_ticketIsLended;
        mapping(address => uint256) s_lastTicket;
        mapping(uint => bool) s_isLocked;
        mapping(address => uint256[]) s_locked_mrCrypto;
        caseTicket[] private _tickets;

        constructor(address _racksItems, address _mrCrypto){
           RacksItems = IRacksItems(_racksItems);
           MR_CRYPTO = IERC721Enumerable(_mrCrypto);

        }
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
    function listTicket(uint256 numTries, uint256 _hours, uint256 price, address user) external  override{
        
        require(msg.sender==address(RacksItems));
        require(!s_isSellingTicket[user], "User is already currently selling a Ticket");
        if(s_hadTicket[user]) {
            require(s_hasTicket[user], "User has not ticket avaliable");
        }
        bool success = _lockMrCrypto(user);
        require(success,"Sorry, you already have a Mr Crypto on use.");
        _tickets.push(
        caseTicket(
        s_ticketCount,
        numTries,
        _hours,
        price,
        user,
        0,
        true
        ));

        s_lastTicket[user] = s_ticketCount;
        s_ticketCount++;
        s_isSellingTicket[user] = true;
        s_hadTicket[user] = true;
        s_hasTicket[user] = false;
    }

     /**
    * @notice This function is used for a VIP user to unlist 'Case Tickets' on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function unListTicket(address user) external override{
        require(msg.sender==address(RacksItems));
        uint ticketId = s_lastTicket[user];
        require(s_isSellingTicket[user], "User is not currently selling a Ticket");
        require(_tickets[ticketId].owner == user, "User is not owner of this ticket");
        _tickets[ticketId].isAvaliable = false;
        s_isSellingTicket[user] = false;
        s_hasTicket[user] = true;
        _unlockMrCrypto(user);
     
    }

    /**
    * @notice This function is used for a VIP user to change 'Case Tickets' price and tries on the MarketPlace
    * @dev - Should check that user is Vip (Modifier)
    * - Should check that user has a listed ticket
    * - Emit event
    */
    function changeTicketConditions(uint256 newTries, uint256 newHours, uint256 newPrice, address user) external override{
        require(msg.sender==address(RacksItems));
        uint ticketId = s_lastTicket[user];
        require(s_isSellingTicket[user], "User is not currently selling a Ticket");
        require(_tickets[ticketId].owner == user, "User is not owner of this ticket");
        _tickets[ticketId].price = newPrice;
        _tickets[ticketId].duration = newHours;
        _tickets[ticketId].numTries = newTries;
     
    }

    /**
    * @notice This function is used to buy a caseTicket
    * @dev - Should check that user is NOT Vip -> does make sense that a VIP user buys a ticket
    * - Should check that user has a listed ticket
    * - Transfer RacksToken from buyer to seller
    * - Update mappings variables
    * - Emit event
    */
    function buyTicket(uint256 ticketId, address user) external override{

        require(msg.sender==address(RacksItems));
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
    function claimTicketBack(address user) external override{

        require(msg.sender==address(RacksItems));
        uint ticketId = s_lastTicket[user];
        require(s_ticketIsLended[user], "User did not sell any Ticket");
        require((_tickets[ticketId].numTries == 0) || (((block.timestamp - _tickets[ticketId].timeWhenSold)/60) == (_tickets[ticketId].duration * 60)), "Duration of the Ticket or numTries is still avaliable");
        s_hasTicket[_tickets[ticketId].owner] = false;
        s_hasTicket[user] = true;
        s_ticketIsLended[user] = false;
        _unlockMrCrypto(user);
  
    }
     function getUserTicket(address user) external view override returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice) {
        require(msg.sender==address(RacksItems));
        if(_ticketOwnership(user)==1 || _ticketOwnership(user)==0 || _ticketOwnership(user)==4){
          return(0,0,_ticketOwnership(user), 0);
        }else{
        uint256 ticketId = s_lastTicket[user];
        (,uint256 timeLeft,) = getTicketDurationLeft(ticketId);
        return (timeLeft, _tickets[ticketId].numTries, _ticketOwnership(user), _tickets[ticketId].price);
        }
    }

    function getMarketTicket(uint256 ticketId) external override view returns( uint256 numTries, uint256 duration, uint256 price, address owner, uint256 timeWhenSold, bool isAvaliable){
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

    /** @notice Function used to decrease Ticket tries avaliables
    * @dev - Check if used trie was last one
    *        - If not: just decrease numTries
    *        - If so: decrease numTries, update Avaliability and mappings
    */
    function decreaseTicketTries(address user) external override {

    require(msg.sender == address(RacksItems));
    uint ticketId = s_lastTicket[user];
            if(_tickets[ticketId].numTries != 1) { // Case it was not the last trie avaliable
                _tickets[ticketId].numTries--;
            }else { // it was his last trie avaliable
                _tickets[ticketId].numTries--;
                s_hasTicket[user] = false;
            }
    
     }

 

    /**
    * @notice Function used to return every ticket that are currently on sale
    */
    function getTicketsOnSale() public view override returns(caseTicket[] memory) {
        require(msg.sender==address(RacksItems));
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

     function getTicketDurationLeft(uint256 ticketId) public view override returns (address, uint256, bool) {
            require(_tickets[ticketId].timeWhenSold>0, "Ticket is not sold yet");
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

     function _mrCryproWallet(address user) internal  view returns (uint256[] memory){

        uint256 ownerTokenCount = MR_CRYPTO.balanceOf(user);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; ++i) {
            tokenIds[i] = MR_CRYPTO.tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }

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

    function getTicketCount() public view returns(uint256) {
        return s_ticketCount;
    }



    }