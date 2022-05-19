// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
    This is a representation of the RacksToken.
 */
contract RacksToken is ERC20("Racks Token", "RCK"), Ownable {

   constructor(address _to, uint256 _amount){ 
        _mint(_to, _amount);                
    }
}