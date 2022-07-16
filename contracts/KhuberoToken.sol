// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./WadMath.sol";

contract KhuberoToken is ERC20, Pausable, Ownable, ReentrancyGuard {

    using WadMath for uint256;
    using Address for address payable;
    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeMath for uint8;

    uint256 public constant WAD = 1e18;
    uint256 public investmentCap;
    uint256 public exchangeRate;
    uint256 public minInvestment;
    uint256 public feePercentage;
    address public immutable Treasury;

    uint256 private ETHSupplied;    //Store the remaining token to be supplied
    address[] private stakeAccounts;   //Store both staker and referer address
    uint256 private constant _DECIMALS = 18;
    uint256 private immutable _MIN_STAKE_AMOUNT;
    uint256 private immutable _MAX_STAKE_AMOUNT;
    uint256 private constant DIVISOR = 100;
    uint256 public FINAL_REWARD_ETH_TO_WITHDRAW = 0;
    uint256 public FINAL_STAKED_TOKENS = 0;
    bool public ALLOW_WITHDRAWAL = false;

    mapping (address => Stake[]) private stake; /// @dev Map that contains account's stakes

    struct Stake{
        uint deposit_amount;        //Deposited Amount
        uint stake_creation_time;   //The time when the stake was created
    }
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
        require(_minInvestment>= 1000000 gwei, "Min investment is 1000000 gwei");
        require(_minInvestment<=_investmentCap, "Min investment is gt Max investment");
        require(_feePct < 100, "fee>=100");
        Treasury = _treasury;
        investmentCap = _investmentCap;
        exchangeRate = _exchangeRate;
        minInvestment = _minInvestment;
        feePercentage = (WAD * _feePct) / 100;
        _MIN_STAKE_AMOUNT = _minInvestment;
        _MAX_STAKE_AMOUNT = investmentCap.wadDivDown(minInvestment);
    }

    event Received(address, uint);
    event FeeRecieved(uint256 fee, uint256 datetime);
    event KBRReceived(address investor, uint256 kbr, uint256 datetime);
    event EthInvestement(address investor, uint256 eth, uint256 datetime);
    event ethWithdrawal(address withdrawal, uint amount);

    event EthSupplyUpdated(address account, uint newETH);
    event NewStake(address staker, uint stakeAmount);
    event rewardWithdrawed(address account, uint amount);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint() public payable whenNotPaused {

        require(ALLOW_WITHDRAWAL==false, "Mint dissallowed");
        
        require(msg.value>=minInvestment, "Below Min Investment.");
    
        require(address(this).balance<=investmentCap, "Investment overflow");

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
        require(ALLOW_WITHDRAWAL==false, "Only investors"); // If ALLOW_WITHDRAWAL is true, only investors can withdraw ether
        payable(address(Treasury)).sendValue(address(this).balance);
        emit ethWithdrawal(msg.sender, address(this).balance);
    }

    // function resetInvestmentCap(uint256 _newCap) external onlyOwner {
    //     require(address(this).balance == 0, "Eth > 0");
    //     require(_newCap >= 1 ether && _newCap > address(this).balance, "cap error");
    //     investmentCap = _newCap;
    // }

    function allowWithdrawal() external onlyOwner {
        require(ALLOW_WITHDRAWAL==false, "Withdraw already allowed");
        require(address(this).balance>0, "No ether");
        FINAL_REWARD_ETH_TO_WITHDRAW = address(this).balance;
        FINAL_STAKED_TOKENS = balanceOf(address(this));
        ALLOW_WITHDRAWAL = true;
    }

    function getAllStakeAccount() external view returns (address[] memory){
        return stakeAccounts;
    }

       /**
    *   @dev Stake token verifying all the contraint
    *   @notice Stake tokens
    *   @param _amount Amoun to stake
     */
    function stakeToken(uint _amount) external nonReentrant {

        require(ALLOW_WITHDRAWAL==false, "Staking period over.");

        require(_amount >= _MIN_STAKE_AMOUNT, "Min stake limit error");
        require(_amount <= _MAX_STAKE_AMOUNT, "Max stake limit error");

        address staker = msg.sender;
        Stake memory newStake;

        require(newStake.deposit_amount.add(_amount)<= _MAX_STAKE_AMOUNT, "Max stake limit is 100000");

        newStake.deposit_amount = _amount;
        newStake.stake_creation_time = block.timestamp;

        if(stake[staker].length==0) {
            stakeAccounts.push(msg.sender);
        }

        stake[staker].push(newStake);

        if(transfer(address(this), _amount)){
            emit NewStake(staker, _amount);
        }else{
            revert("Unable to transfer funds");
        }
    }

    function outputETHReward(uint deposited_amount) view public returns (uint outputEth) {
        outputEth = (deposited_amount.mul(FINAL_REWARD_ETH_TO_WITHDRAW)).div(FINAL_STAKED_TOKENS);
    }

    // Withdraw reward in Ether
    function withdrawReward() external nonReentrant {

        require(ALLOW_WITHDRAWAL==true, "Withdrawal not allowed yet");

        uint deposited_amount = getTotalStakeAmount(); 

        uint outputEth = outputETHReward(deposited_amount);

        if(outputEth > address(this).balance) {
            revert("Insufficient ETH");
        }

        if(outputEth>0) {
            require(removeTotalStakeAmount(), "removeTotalStakeAmount failed.");
            require(getTotalStakeAmount()==0, "getTotalStakeAmount==0");
            // Burn tokens
            _burn(address(this), deposited_amount);
            payable(address(msg.sender)).sendValue(outputEth);
            emit rewardWithdrawed(msg.sender, outputEth);
        } else {
            revert("WithdrawReward failed.");
        }

    }


    //--------------------------------------------------------------------
    //-------------------------- VIEWS -----------------------------------
    //--------------------------------------------------------------------

    /**
    * @dev Return the amount of token in the provided caller's stake
    * @param _stakeID The ID of the stake of the caller
     */
    function getCurrentStakeAmount(uint _stakeID) external view returns (uint256)  {
        return stake[msg.sender][_stakeID].deposit_amount;
    }

    /**
    * @dev Return sum of all the caller's stake amount
    * @return Amount of stake
     */
    function getTotalStakeAmount() public view returns (uint256) {
        Stake[] memory currentStake = stake[msg.sender];
        uint nummberOfStake = stake[msg.sender].length;
        uint totalStake = 0;
        uint tmp;
        for (uint i = 0; i<nummberOfStake; i++){
            tmp = currentStake[i].deposit_amount;
            totalStake = totalStake.add(tmp);
        }

        return totalStake;
    }

        /**
    * @dev Remove all the caller's stake amount
    * @return bool
     */
    function removeTotalStakeAmount() internal returns (bool) {
        Stake[] storage currentStake = stake[msg.sender];
        uint nummberOfStake = stake[msg.sender].length;
        for (uint i = 0; i<nummberOfStake; i++){
            currentStake[i].deposit_amount = 0;
        }

        return true;
    }

    /**
    *   @dev Return all the available stake info
    *   @notice Return stake info
    *   @param _stakeID ID of the stake which info is returned
    *
    *   @return 1) Amount Deposited
    *   @return 2) Stake creation time (Unix timestamp)
    *   @return 3) The probable eth reward
    */
    function getStakeInfo(address account, uint _stakeID) external view returns(uint, uint){

        Stake memory selectedStake = stake[account][_stakeID];

        return (
            selectedStake.deposit_amount,
            selectedStake.stake_creation_time
        );
    }

    /**
    * @dev Get the number of active stake of the caller
    * @return Number of active stake
     */
    function getStakeCount() external view returns (uint){
        return stake[msg.sender].length;
    }


    function getActiveStakeCount() external view returns(uint){
        uint stakeCount = stake[msg.sender].length;

        uint count = 0;

        for(uint i = 0; i<stakeCount; i++) {
            count = count + 1;
        }
        return count;
    }

}