pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    address public tokenAddress;
    constructor(address _token) {
        require(_token != address(0));
        tokenAddress = _token;
    }

    function addLiquidity(uint256 _tokenAmount) public payable {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }
    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0);
        return inputReserve * 1000 / outputReserve;
    }

    function getAmount(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0);
        return (inputAmount * outputReserve) / (inputReserve + inputAmount);
    }

    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0);
        uint256 reserve = getReserve();
        return getAmount(_tokenSold, reserve, address(this).balance);
    }

    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0);
        uint256 reserve = getReserve();
        return getAmount(_ethSold, address(this).balance, reserve);
    }    

    function ethToTokenSwap(uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);
        // protect front running
        require(tokensBought >= _minTokens);
        IERC20(tokenAddress).transfer(msg.sender, tokensBought);
    }

    function tokenToEthSwap(uint256 tokenAmount, uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(tokenAmount, tokenReserve, address(this).balance);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethBought);
    }
}