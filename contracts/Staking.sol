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

    uint256 private constant _INTEREST_PERIOD = 1 seconds;   
    uint256 private constant _INTEREST_VALUE = 333;    //0.333% per period

    uint256 private constant _MIN_STAKE_AMOUNT = 1 * (10**_DECIMALS);

    uint256 private constant _MAX_STAKE_AMOUNT = 100 * (10**_DECIMALS);

    uint256 private constant DIVISOR = 100;

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

        require(ALLOW_WITHDRAWAL==false, "Staking period over.");

        require(_amount >= _MIN_STAKE_AMOUNT, "Min stake limit is 100");
        require(_amount <= _MAX_STAKE_AMOUNT, "Max stake limit is 100000");

        address staker = msg.sender;
        Stake memory newStake;

        require(newStake.deposit_amount.add(_amount)<= _MAX_STAKE_AMOUNT, "Max stake limit is 100000");

        newStake.deposit_amount = _amount;
        newStake.stake_creation_time = block.timestamp;

        if(stake[staker].length==0) {
            activeAccounts.push(msg.sender);
        }

        stake[staker].push(newStake);

        if(ERC20Interface.transferFrom(msg.sender, address(this), _amount)){
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
            //ERC20Interface.transfer(address(0), deposited_amount);
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
    function removeTotalStakeAmount() internal returns (bool) {
        require(tokenAddress != address(0), "No contract set");

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
    function getStakeInfo(address account, uint _stakeID) external view returns(uint, uint, uint){

        Stake memory selectedStake = stake[account][_stakeID];

        uint probableETHReward = outputETHReward(selectedStake.deposit_amount);

        return (
            selectedStake.deposit_amount,
            selectedStake.stake_creation_time,
            probableETHReward
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
    
    function getContractTokenBalance() external view returns (uint) {
        return ERC20Interface.balanceOf(address(this));
    }

}
