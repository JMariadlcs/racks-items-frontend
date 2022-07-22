// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IRacksItems.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol"; 


interface  ITickets{

    struct caseTicket {
        uint256 ticketId;
        uint256 numTries;
        uint256 duration;
        uint256 price;
        address owner;
        uint256 timeWhenSold;
        bool isAvaliable;
    }
    

    
    
    
    function listTicket(address from ,uint256 numTries, uint256 _hours, uint256 price, address user) external;

    function unListTicket(address from, address user) external;

    function changeTicketConditions(address from , uint256 newTries, uint256 newHours, uint256 newPrice, address user) external;

    function buyTicket(uint256 ticketId, address user) external;

    function claimTicketBack(address from , address user) external;

    function decreaseTicketTries(address user) external;

    function approveTicket(address owner, address spender, bool permission) external;

    function getUserTicket(address user) external view  returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice);

    function getMarketTicket(uint256 ticketId) external  view returns( uint256 numTries, uint256 duration, uint256 price, address owner, uint256 timeWhenSold, bool isAvaliable);

    function ticketAllowance(address owner, address spender) external  view returns(bool);

    function isApproved(address user) external  view returns(bool);

    function getTicketsOnSale() external view  returns(caseTicket[] memory);

    function getTicketCount() external view returns(uint256);


    }