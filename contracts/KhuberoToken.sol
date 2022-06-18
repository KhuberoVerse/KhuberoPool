// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./WadMath.sol";
import "hardhat/console.sol";

contract KhuberoToken is ERC20, Pausable, Ownable {

    using WadMath for uint256;
    using Address for address payable;

    uint256 public constant WAD = 1e18;
    uint256 public investmentCap;
    uint256 public exchangeRate;
    uint256 public minInvestment;
    uint256 public feePercentage;
    address public immutable Treasury;
    constructor(
        address _treasury,
        uint256 _investmentCap, 
        uint256 _exchangeRate, 
        uint256 _minInvestment, 
        uint8 _feePct) ERC20("KhuberoToken", "KBR") 
    {

        require(_treasury != address(0), "Invalid treasury address");
        require(_investmentCap>= 1 ether, "Min cap in 1 ether");
        require(_exchangeRate>= 1, "Invalid Exchange rate");
        require(_minInvestment>= 1 ether, "Min investment is 1 ether");
        require(_feePct < 100, "fee>=100");
        Treasury = _treasury;
        investmentCap = _investmentCap;
        exchangeRate = _exchangeRate;
        minInvestment = _minInvestment;
        feePercentage = (WAD * _feePct) / 100;

        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    event Received(address, uint);
    event FeeRecieved(uint256 fee, uint256 datetime);
    event KBRReceived(address investor, uint256 kbr, uint256 datetime);
    event EthInvestement(address investor, uint256 eth, uint256 datetime);
    event ethWithdrawal(address withdrawal, uint amount);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint() public payable {
        
        require(msg.value>=minInvestment, "Below Min Investment.");
        require(address(this).balance+msg.value<=investmentCap, "Investment overflow");
        
        uint256 mintedKBR = ethToKBR(msg.value);

        (uint256 outputKBR, uint256 fee) = getPlatformFee(mintedKBR);

        _mint(msg.sender, outputKBR);
        _mint(Treasury, fee);
        
        emit KBRReceived(msg.sender, outputKBR, block.timestamp);
        emit EthInvestement(msg.sender, msg.value, block.timestamp);
        emit FeeRecieved(fee, block.timestamp);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function ethBalance(address _addr) public view returns (uint) {
        return address(_addr).balance;
    }

    function ethToKBR(uint256 ethSent) public view returns(uint256) {
        return ethSent.wadDivDown(exchangeRate);
    }

    function getPlatformFee(uint256 inputKBR) public view returns (uint256 outputKBR, uint256 fee) {
        fee = (inputKBR*feePercentage)/WAD;
        outputKBR = inputKBR - fee;
        require(outputKBR<=inputKBR, "invalid output KBR");
    }

    // Admin actions

    function withdrawEth() external onlyOwner {
        payable(address(Treasury)).sendValue(address(this).balance);
        emit ethWithdrawal(msg.sender, address(this).balance);
    }

    function resetInvestmentCap(uint256 _newCap) external onlyOwner {
        require(_newCap >= 1 ether && _newCap > address(this).balance, "cap error");
        investmentCap = _newCap;
    }

}