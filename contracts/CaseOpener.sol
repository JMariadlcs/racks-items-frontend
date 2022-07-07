pragma solidity ^0.8.0;
import "./IRacksItems.sol";
import "./ICaseOpener.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";   
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol"; 
// 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
// 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f
contract caseItem is ICaseOpener , VRFConsumerBaseV2{

    IRacksItems RacksItems;
    VRFCoordinatorV2Interface public immutable i_vrfCoordinator; 
    bytes32 public immutable i_gasLane;
    uint64 public immutable i_subscriptionId;
    uint32 public immutable i_callbackGasLimit;
    uint16 public constant REQUEST_CONFIRMATIONS = 3; 
    uint32 public constant NUM_WORDS = 2; 
    uint256 public s_randomWord;


    constructor(address _racksItems,address vrfCoordinatorV2, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinatorV2){
        RacksItems = IRacksItems(_racksItems);
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); 
        i_gasLane = gasLane; 
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit; 
        

    }   
  


    function openCase() external override returns(uint)  {  
        require(msg.sender == address(RacksItems));
        uint caseSupply;
        uint256 [] memory itemList = RacksItems.caseLiquidity();
        for(uint i =0 ;i<itemList.length; i++){
          caseSupply+=RacksItems.supplyOfItem(itemList[i]);
        }
        uint256 randomNumber = _randomNumber()  % caseSupply;
        uint256 totalCount = 0;
        uint256 item;

        for(uint256 i = 0 ; i < itemList.length; i++) {
          uint256 _newTotalCount = totalCount + RacksItems.supplyOfItem(itemList[i]) ;
          if(randomNumber > _newTotalCount) {
            totalCount = _newTotalCount;
          }else {
            item = itemList[i];
            break;
          }
        }
        return item;
       
    }

    
     /**
    * @notice Used to get an actually Random Number -> to pick an item when openning a case
    * @dev Uses Chainlink VRF -> call requestRandomWords method by using o_vrfCoordinator object
    * set as internal because is going to be called only when a case is opened
    */

    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override {
        s_randomWord = randomWords[0]; // just in case random number is very long we apply modular function 
    }

    /**
    * @notice Function to actually pick a winner 
    * @dev 
    * - randomWords -> array of randomWords
    */

    function _randomNumber() internal returns(uint256) {
        uint256 s_requestedNumber = i_vrfCoordinator.requestRandomWords(i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS);
        return s_requestedNumber;
    }
}