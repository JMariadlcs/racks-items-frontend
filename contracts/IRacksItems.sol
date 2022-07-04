// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRacksItems { 

    /**
    * @notice Struct for Items on the Marketplace
    */
    struct itemOnSale{
    uint256 tokenId;
    uint256 marketItemId;
    uint256 price;
    address itemOwner;
    bool isOnSale;
    }

    /**
    * @notice Struct for Tickets on the Marketplace
    */
    struct caseTicket {
    uint256 ticketId;
    uint256 numTries;
    uint256 duration;
    uint256 price;
    address owner;
    uint256 timeWhenSold;
    bool isAvaliable;
    }

    /// @notice Events
    event CaseOpened(address user, uint256 casePrice, uint256 item);
    event casePriceChanged(uint256 newPrice);
    event itemExchanged(address user, uint256 tokenId);
    event sellingItem(address user, uint256 tokenId, uint256 price);
    event itemBought(address buyer, address seller, uint256 marketItemId, uint256 price);
    event unListedItem(address owner, uint256 marketItemId);
    event itemPriceChanged(address owner, uint256 marketItemId, uint256 oldPrice, uint256 newPrice);
    event newTicketOnSale(address seller, uint256 numTries, uint256 _hours, uint256 price);
    event unListTicketOnSale(address owner);
    event ticketConditionsChanged(address owner, uint256 newTries, uint256 newHours, uint256 newPrice);
    event ticketBought(uint256 ticketId, address oldOwner, address newOwner, uint256 price);
    event ticketClaimedBack(address borrower, address realOwner);

    function openCase() external;

    function caseLiquidity() external view returns(uint256[] memory);

    function supplyOfItem(uint256 tokenId) external view returns(uint);


    function viewItems(address owner) external view returns(uint256[] memory);

    function listItemOnMarket(uint256 marketItemId, uint256 price) external;

    function unListItem(uint256 marketItemId) external;

    function changeItemPrice(uint256 marketItemId, uint256 newPrice) external;

    function exchangeItem(uint256 tokenId) external;

    function buyItem(uint256 marketItemId) external;

    function getMarketItem(uint marketItemId) external view returns(itemOnSale memory);

    function getItemsOnSale() external view returns(itemOnSale[] memory);

    function listTicket(uint256 numTries, uint256 _hours, uint256 price) external;

    function unListTicket() external;

    function changeTicketConditions( uint256 newTries, uint256 newHours, uint256 newPrice) external;

    function buyTicket(uint256 ticketId) external;

    function claimTicketBack() external;

    function getMarketTicket(uint256 ticketId) external view returns(caseTicket memory);

    function getTicketsOnSale() external view returns(caseTicket[] memory);

    function getTicketDurationLeft(uint256 ticketId) external view returns (address, uint256, bool);

    function getUserTicket(address user) external view returns(uint256 durationLeft, uint256 triesLeft, uint ownerOrSpender, uint256 ticketPrice);

    function isVip(address user) external view returns(bool);

    function setAdmin(address _newAdmin) external;

    function setTokenUri(uint256 tokenId, string memory _uri) external;

    function withdrawFunds(address wallet, uint256 amount) external;

    function withdrawAllFunds(address wallet) external; 
}