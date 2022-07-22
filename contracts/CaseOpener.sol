// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IRacksItems.sol";
import "./ICaseOpener.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";   
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 

contract caseItem is ICaseOpener , VRFConsumerBaseV2{

  /// @notice contracts
  IRacksItems RacksItems;

  /// @notice VRF Variables
  VRFCoordinatorV2Interface public immutable i_vrfCoordinator; 
  bytes32 public immutable i_gasLane;
  uint64 public immutable i_subscriptionId;
  uint32 public immutable i_callbackGasLimit;
  uint16 public constant REQUEST_CONFIRMATIONS = 3; 
  uint32 public constant NUM_WORDS = 2; 
  uint256 public s_randomWord;

  /// @notice Mappings
  mapping (uint => address) private s_requestIdOfUser; // maps each requestId to the user that made it

  /// @notice Modifiers
  modifier notForUsers(){
    require(msg.sender==address(RacksItems),"This function is specially reserved for the main contract.");
    _;
  }

  constructor(address _racksItems,address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinatorV2){
    RacksItems = IRacksItems(_racksItems);
    /**
    * Initialization of Chainlink VRF variables
    */
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); 
    i_gasLane = gasLane; 
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit; 
  }   

  /**
  * @notice Function used to 'open a case' and get an item
  * @dev Saves the requestId made to ChainlinkVRF in order to identify the user later
  */
  function _generate(address user) external override notForUsers { 
    uint256 requestId = i_vrfCoordinator.requestRandomWords(i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS);
    s_requestIdOfUser[requestId] = user;  
  }

  
  /**
  * @notice Used to get an actually Random Number -> to pick an item when openning a case
  * @dev Uses Chainlink VRF -> When the oracle returns the random number back calls the main contract passing the random number and the user that made the call
  * The main contract will then pick the item the user won based on the random number and will send it to him.
  * set as internal because is going to be called only when a case is opened
  */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    address recipient = s_requestIdOfUser[requestId];
    uint256 randomNumber = randomWords[0];
    RacksItems.fulfillCaseRequest(recipient, randomNumber); 
  }
}