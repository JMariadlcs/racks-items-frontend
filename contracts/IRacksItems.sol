
interface IRacksItems{ 


    struct itemOnSale{
        uint tokenId;
        uint price;
        address payable seller;
        bool isRacksTrack;
        bool sold;
  }


  /**
  * @notice Enum for Contract state -> to let user enter call some functions or not
  */
  
  /// @notice Events
  event RacksTrackMinted(uint baseItemId, uint rackstrackItemId);
  event CaseOpened(address user, uint256 casePrice, uint256 item);
  event itemExchanged(address user , uint tokenId, bool isRacksTrack );
  
  /// @notice Modifiers
  /// @notice Check that person calling a function is the owner of the Contract
 



  /** 
  * @notice Need to override supportsInterface function because Contract is ERC1155 and AccessControl
  */


   /**
  * @notice Function used to 'open a case' and get an item
  * @dev 
  * - Internally calls randomNumber() 
  * - Should choose an item
  * - Should check if the item is RacksTrack (special NFT)
  *   - If it is a RacksTrack -> mint ERC721 to users wallet
  */
  function openCase() external payable returns(uint256);

  function sellItem(uint tokenId ,uint  price) external;

  function buyItem(uint marketItemId) external payable;

  function getItemsOnSale() external view returns(itemOnSale[] memory);

  // FUNCTIONS RELATED TO ITEMS

  /**
  * @notice Returns maxSupply of specific item (by tokenId)
  * @dev - Getter of s_maxSupply mapping
  */
  function supplyOfItem(uint256 tokenId) external view returns(uint) {
    return s_maxSupply[tokenId];
  }

  /**
  * @notice Calculate chance of receiving an specific item
  * @dev - Requires that tokenId exists (item is listed)
  * - chance is calculated as item supply divided by total items supply
  */
  function chanceOfItem(uint256 tokenId) external virtual view returns(uint256) ;

  /**
  * @notice Returns all the items inside the user's inventory (Could be used by the
  * user to check his inventory or to check someone else inventory by address)
  * @dev Copy users inventory in an empty array and returns it
  */
  function viewItems(address owner) external view returns(uint256[] memory) ;


  


  // FUNCTIONS RELATED TO "USERS"

  /**
  * @notice Check if user is RacksMembers and owns at least 1 MrCrypto
  * @dev - Require users MrCrypro's balance is > '
  * - Require that RacksMembers user's attribute is true
  */
  function isVip(address user) external view returns(bool);

  
}