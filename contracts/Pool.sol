// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./KhuberoToken.sol";
import "./WadMath.sol";

contract Pool {

    using WadMath for uint256;

    uint256 public constant WAD = 1e18;
    uint256 public investmentCap;
    uint256 public investmentTub;
    uint256 public exchangeRate;
    uint256 public minInvestment;
    uint256 public feePercentage;
    address[] public investorsList;

    address public Treasury;
    KhuberoToken public KBRContract;

    constructor(address _treasury,
                address _KBRContract, 
                uint256 _investmentCap, 
                uint256 _exchangeRate, 
                uint256 _minInvestment, 
                uint8 _feePct) 
    {
        require(_treasury != address(0), "Invalid treasury address");
        require(_KBRContract != address(0), "Invalid KBR address");
        require(_investmentCap>= 1 ether, "Min cap in 1 ether");
        require(_exchangeRate>= 1, "Invalid Exchange rate");
        require(_minInvestment>= 1 ether, "Min investment is 1 ether");
        require(_feePct < 100, "fee>=100");
        KBRContract = KhuberoToken(_KBRContract);
        Treasury = _treasury;
        investmentCap = _investmentCap;
        exchangeRate = _exchangeRate;
        minInvestment = _minInvestment;
        feePercentage = (WAD * _feePct) / 100;
    }

    event Received(address, uint);
    event FeeRecieved(uint256 fee, uint256 datetime);
    event KBRReceived(address investor, uint256 kbr, uint256 datetime);
    event EthInvestement(address investor, uint256 eth, uint256 datetime);
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    mapping(address => uint256) public ethInvestments;
    mapping(address => uint256) public KBRHoldings;

    function ethToKBR(uint256 ethSent) public view returns(uint256) {
        return ethSent.wadDivDown(exchangeRate);
    }

    function getPlatformFee(uint256 inputKBR) public view returns (uint256 outputKBR, uint256 fee) {
        fee = (inputKBR*feePercentage)/WAD;
        outputKBR = inputKBR - fee;
        require(outputKBR<=inputKBR, "invalid output KBR");
    }

    function getInvestorsList() public view returns (address[] memory) {
        return investorsList;
    }

    function calcShare(address _addr) public view returns (uint256) {
        return (ethInvestments[_addr].wadDivUp(address(this).balance));
    }

    function invest(bytes32[] memory _merkleProof) external payable {
        require(msg.value>minInvestment, "Below Min Investment.");
        require(investmentTub+msg.value<=investmentCap, "Investment overflow");
        
        investmentTub += msg.value;
        
        uint256 mintedKBR = ethToKBR(msg.value);

        (uint256 outputKBR, uint256 fee) = getPlatformFee(mintedKBR);

        KBRContract.mint(msg.sender, outputKBR, _merkleProof);
        KBRContract.mint(Treasury, fee, _merkleProof);

        ethInvestments[msg.sender] += msg.value;
        KBRHoldings[msg.sender] += outputKBR;

        investorsList.push(msg.sender);
        
        emit KBRReceived(msg.sender, outputKBR, block.timestamp);
        emit EthInvestement(msg.sender, msg.value, block.timestamp);
        emit FeeRecieved(fee, block.timestamp);
    }

}