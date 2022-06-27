// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Staking is Ownable, ReentrancyGuard {

    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeMath for uint8;
    using Address for address payable;

    struct Stake{
        uint deposit_amount;        //Deposited Amount
        uint stake_creation_time;   //The time when the stake was created
    }


    //---------------------------------------------------------------------
    //-------------------------- EVENTS -----------------------------------
    //---------------------------------------------------------------------


    /**
    *   @dev Emitted when the ETH value changes
    */
    event EthSupplyUpdated(
        address account,
        uint newETH
    );

    /**
    *   @dev Emitted when a new stake is issued
     */
    event NewStake(
        address staker,
        uint stakeAmount
    );

    event rewardWithdrawed(
        address account,
        uint amount
    );

    //--------------------------------------------------------------------
    //-------------------------- GLOBALS -----------------------------------
    //--------------------------------------------------------------------

    mapping (address => Stake[]) private stake; /// @dev Map that contains account's stakes

    address private tokenAddress;

    ERC20 private ERC20Interface;

    uint256 private ETHSupplied;    //Store the remaining token to be supplied

    address[] private activeAccounts;   //Store both staker and referer address

    uint256 private constant _DECIMALS = 18;

    uint256 private constant _INTEREST_PERIOD = 1 days;    //One Month
    uint256 private constant _INTEREST_VALUE = 333;    //0.333% per day

    uint256 private constant _MIN_STAKE_AMOUNT = 100 * (10**_DECIMALS);

    uint256 private constant _MAX_STAKE_AMOUNT = 100000 * (10**_DECIMALS);

    uint256 private constant _MAX_TOKEN_SUPPLY_LIMIT =     50000000 * (10**_DECIMALS);

    uint256 private constant DIVISOR = 100000;

    uint256 public FINAL_REWARD_ETH_TO_WITHDRAW = 0;
    uint256 public FINAL_STAKED_TOKENS = 0;

    bool public ALLOW_WITHDRAWAL = false;


    constructor(address _tokenAddress) {
        require(Address.isContract(_tokenAddress), "The address does not point to a contract");
        tokenAddress = _tokenAddress;
        ERC20Interface = ERC20(tokenAddress);
    }

    //--------------------------------------------------------------------
    //-------------------------- TOKEN ADDRESS -----------------------------------
    //--------------------------------------------------------------------

    function isTokenSet() external view returns (bool) {
        if(tokenAddress == address(0))
            return false;
        return true;
    }

    function getTokenAddress() external view returns (address){
        return tokenAddress;
    }

    receive() external payable {
        require(tokenAddress != address(0), "The Token Contract is not specified");
        emit EthSupplyUpdated(msg.sender, msg.value);
    }

    function allowWithdrawal() external {
        FINAL_REWARD_ETH_TO_WITHDRAW = address(this).balance;
        FINAL_STAKED_TOKENS = ERC20Interface.balanceOf(address(this));
        ALLOW_WITHDRAWAL = true;
    }

    function getAllAccount() external view returns (address[] memory){
        return activeAccounts;
    }


    //--------------------------------------------------------------------
    //-------------------------- CLIENTS -----------------------------------
    //--------------------------------------------------------------------

    /**
    *   @dev Stake token verifying all the contraint
    *   @notice Stake tokens
    *   @param _amount Amoun to stake
     */
    function stakeToken(uint _amount) external nonReentrant {

        require(tokenAddress != address(0), "No contract set");

        require(_amount >= _MIN_STAKE_AMOUNT, "Min stake limit is 100");
        require(_amount <= _MAX_STAKE_AMOUNT, "Max stake limit is 100000");

        address staker = msg.sender;
        Stake memory newStake;

        require(newStake.deposit_amount.add(_amount)<= _MAX_STAKE_AMOUNT, "Max stake limit is 100000");

        newStake.deposit_amount = _amount;
        newStake.stake_creation_time = block.timestamp;

        stake[staker].push(newStake);

        activeAccounts.push(msg.sender);

        if(ERC20Interface.transferFrom(msg.sender, address(this), _amount)){
            emit NewStake(staker, _amount);
        }else{
            revert("Unable to transfer funds");
        }
    }

    function outputETHReward(uint deposited_amount) view public returns (uint outputEth) {
        uint rewardTokens = deposited_amount.add(calculateTotalRewardToWithdraw(msg.sender));
        outputEth = (rewardTokens.div(FINAL_STAKED_TOKENS)).mul(FINAL_REWARD_ETH_TO_WITHDRAW);
    }

    // Withdraw reward in Ether
    function withdrawReward() external nonReentrant {

        require(ALLOW_WITHDRAWAL==true, "Withdrawal not allowed yet");

        uint deposited_amount = getTotalStakeAmount(); 

        uint outputEth = outputETHReward(deposited_amount);

        if(outputEth <= address(this).balance) {
            revert("ETH exhausted");
        }

        if(outputEth>0) {
            require(removeTotalStakeAmount(), "removeTotalStakeAmount failed.");
            require(getTotalStakeAmount()==0, "removeTotalStakeAmount failed.");
            // Burn tokens
            ERC20Interface.transfer(address(0), deposited_amount);
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
        require(tokenAddress != address(0), "No contract set");

        return stake[msg.sender][_stakeID].deposit_amount;
    }

    /**
    * @dev Return sum of all the caller's stake amount
    * @return Amount of stake
     */
    function getTotalStakeAmount() public view returns (uint256) {
        require(tokenAddress != address(0), "No contract set");

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
    function removeTotalStakeAmount() internal view returns (bool) {
        require(tokenAddress != address(0), "No contract set");

        Stake[] memory currentStake = stake[msg.sender];
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
    *   @return 3) The current amount
    */
    function getStakeInfo(address account, uint _stakeID) external view returns(uint, uint, uint){

        Stake memory selectedStake = stake[account][_stakeID];

        uint amountToWithdraw = calculateRewardTokens(account, _stakeID);

        return (
            selectedStake.deposit_amount,
            selectedStake.stake_creation_time,
            amountToWithdraw
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

    function calculateRewardTokens(address _account, uint _stakeID) public view returns (uint){
        Stake memory _stake = stake[_account][_stakeID];

        uint amount_staked = _stake.deposit_amount;
     
        uint periods = calculateAccountStakePeriods(_account, _stakeID);  //Periods for interest calculation

        uint interest = amount_staked.mul(_INTEREST_VALUE);

        uint reward = interest.mul(periods).div(DIVISOR);

        return reward;
    }

    function calculateTotalRewardToWithdraw(address _account) public view returns (uint){
        Stake[] memory accountStakes = stake[_account];

        uint stakeNumber = accountStakes.length;
        uint amount = 0;

        for( uint i = 0; i<stakeNumber; i++){
            amount = amount.add(calculateRewardTokens(_account, i));
        }

        return amount;
    }

    function calculateAccountStakePeriods(address _account, uint _stakeID) public view returns (uint){
        Stake memory _stake = stake[_account][_stakeID];

        uint creation_time = _stake.stake_creation_time;
        uint current_time = block.timestamp;

        uint total_period = current_time.sub(creation_time);

        uint periods = total_period.div(_INTEREST_PERIOD);

        return periods;
    }
    
    function getContractTokenBalance() external view returns (uint) {
        return ERC20Interface.balanceOf(address(this));
    }

}
