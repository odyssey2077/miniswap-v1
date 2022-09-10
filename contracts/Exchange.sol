pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
    function getExchange(address) external returns (address);
}

contract Exchange is ERC20 {
    address public tokenAddress;
    address public factoryAddress;
    constructor(address _token) ERC20("miniswap-v1", "MINISWAP-V1"){
        require(_token != address(0));
        tokenAddress = _token;
        factoryAddress = msg.sender;
    }

    function addLiquidity(uint256 _tokenAmount) public payable returns (uint256) {
        if (getReserve() == 0) {
            require(msg.value > 0);
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);    
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
        } else {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
            require(tokenAmount <= _tokenAmount);
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);            

            uint256 liquidity = (totalSupply() * msg.value) / address(this).balance;
            _mint(msg.sender, liquidity);
            return liquidity;
        }

    }

    function removeLiquidity(uint256 _amount) public returns (uint256, uint256) {
        require(_amount > 0);
        uint256 ethAmount = (_amount * address(this).balance) / totalSupply();
        uint256 tokenAmount = (_amount * getReserve()) / totalSupply();
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
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
        // take fees
        return (inputAmount * 99 * outputReserve) / (inputReserve * 100 + inputAmount * 99);
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

    function _ethToToken(uint256 _minTokens, address recipient) private {
        uint256 tokenReserve = getReserve();
        uint256 tokensBought = getAmount(msg.value, address(this).balance - msg.value, tokenReserve);
        // protect front running
        require(tokensBought >= _minTokens);
        IERC20(tokenAddress).transfer(recipient, tokensBought);
    }

    function ethToTokenSwap(uint256 _minTokens) public payable {
        _ethToToken(_minTokens, msg.sender);
    }

    function ethToTokenTransfer(uint256 _minTokens, address recipient) public payable {
        _ethToToken(_minTokens, recipient);
    }

    function tokenToEthSwap(uint256 tokenAmount, uint256 _minTokens) public payable {
        uint256 tokenReserve = getReserve();
        uint256 ethBought = getAmount(tokenAmount, tokenReserve, address(this).balance);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethBought);
    }

    function tokenToTokenSwap(uint256 _tokenSold, uint256 _minTokensBought, address _tokenAddress) public {
        address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
        require(exchangeAddress != address(this) && exchangeAddress != address(0));
        Exchange exchange = Exchange(exchangeAddress);

        uint256 ethReceived = getEthAmount(_tokenSold);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenSold);
        uint256 tokenReceived = exchange.getTokenAmount(ethReceived);
        exchange.ethToTokenTransfer{value: ethReceived}(_minTokensBought, msg.sender);
    }
}