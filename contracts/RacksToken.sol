// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

/**
    This is a representation of the RacksToken.
 */
contract RacksToken is ERC20("Racks Token", "RCK") {
    
    // implement the mint function
    function mint(address _to, uint256 _amount) public { 
        _mint(_to, _amount);                
    }
}