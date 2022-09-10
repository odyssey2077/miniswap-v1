pragma solidity ^0.8.0;
import "./Exchange.sol";

contract Factory {
    mapping(address => address) public tokenToExchange;

    constructor() {

    }

    function createExchange(address _tokenAddress) public returns (address) {
        require(_tokenAddress != address(0));
        require(tokenToExchange[_tokenAddress] == address(0));
        
        Exchange exchange = new Exchange(_tokenAddress);
        tokenToExchange[_tokenAddress] = address(exchange);
        return address(exchange);
    }

    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress];
    }
}