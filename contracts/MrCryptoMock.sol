import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
pragma solidity ^0.8.0;

contract MRCryptoMockToken is ERC721Enumerable{
    uint counter;
    constructor() ERC721("MR Crypto by RacksMafia","MRC"){

    }
    function mint(address receiver) public{
        counter ++;
        _mint(receiver, counter);
    }

}