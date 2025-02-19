// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Staking Contract
 * @dev This contract allows an owner to manage staking activities. 
 * The owner stakes on the behalf of the Stakeholders and the contract tracks their stake initiation time and amount.
 * It also provides functionality to calculate rewards based on the duration of the stake. Rewards are calculated as 3% of the staked amount for every month elapsed.
 */

contract Staking is Ownable {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Struct to store staker information
    struct Staker {
        uint8 monthsRewarded;
        uint32 stakeInitTime;
        uint256 stakeAmount;
        uint256 rewardsReceived;
    }

    // State variables
    address public token; //the token to be staked
    address[] private stakersAddresses; //array to store staker addresses

    uint8 public constant MONTHLY_REWARD_PERCENTAGE = 3; //% of the stake amount to be rewarded monthly after the lock period
    uint8 public constant LOCK_PERIOD_MONTHS = 3; //the lock period in months

    // Mapping to store staker information
    mapping(address => Staker) public stakingInfo;

    // Events
    event StakeRemoved(address indexed staker);

    // Error messages
    error AmountMustBeBiggerThanaThousand();
    error StakerAlreadyExists();
    error ArraysLengthMismatch();
    error StakerDoesNotExist(address stakerAddress);
    error LockPeriodNotOver();
    error UserNoLongerStaking();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _token) Ownable(msg.sender) {
        token = _token;
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
    * @notice Allows the owner to stake tokens on behalf of a stakeholder.
    * @dev Creates a new staking record for the specified stakeholder. Requires that the stakeholder does not already have an active stake
    *      and that the stake amount is greater than zero. The staked amount is doubled and transferred from the owner's address (since the total reward is 100%).
    * @param stakeAmount The amount of tokens to be staked.
    * @param stakeRecipient The address of the stakeholder for whom the tokens are being staked.
    *
    * Requirements:
    * - `stakeAmount` must be greater than zero.
    * - The recipient must not already have an active stake.
    * - The owner must have sufficient token allowance for the contract to transfer the staked amount.
    *
    * Emits:
    * - Adds a new entry in `stakingInfo` for the `stakeRecipient`.
    * - Updates the `stakersAddresses` array to include the `stakeRecipient`.
    */
    function stake(address stakeRecipient, uint256 stakeAmount) public onlyOwner{

        if(stakeAmount <= 0){
            revert AmountMustBeBiggerThanaThousand();
        }

        if(stakingInfo[stakeRecipient].stakeAmount > 0){
            revert StakerAlreadyExists();
        }

        uint256 tokenAmount = stakeAmount * 2;
        IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);

        // Create new staker instance and map it to staker address
        Staker memory newStaker = Staker(0, uint32(block.timestamp), stakeAmount, 0);
        stakingInfo[stakeRecipient] = newStaker;

        // Add staker address to stakersAddresses array
        stakersAddresses.push(stakeRecipient);

    }


/**
* @notice Allows the owner to stake tokens on behalf of multiple stakeholders.
* @dev Creates new staking records for the specified stakeholders. Requires that each stakeholder does not already have an active stake
*      and that each stake amount is greater than zero. The staked amount for each recipient is doubled and transferred from the owner's address.
* @param stakeRecipients The array of stakeholder addresses for whom the tokens are being staked.
* @param stakeAmounts The array of token amounts to be staked for each stakeholder.
*
* Requirements:
* - `stakeRecipients` and `stakeAmounts` must have the same length.
* - Each `stakeAmount` must be greater than zero.
* - Each recipient must not already have an active stake.
* - The owner must have sufficient token allowance for the contract to transfer the staked amounts.
*
* Emits:
* - Adds new entries in `stakingInfo` for each `stakeRecipient`.
* - Updates the `stakersAddresses` array to include the `stakeRecipients`.
*/
function stakeMultiple(address[] memory stakeRecipients, uint256[] memory stakeAmounts) public onlyOwner {
    if (stakeRecipients.length != stakeAmounts.length) {
        revert ArraysLengthMismatch();
    }

    uint256 totalAmount = sumArray(stakeAmounts) * 2;
    IERC20(token).transferFrom(msg.sender, address(this), totalAmount);

    for (uint256 i = 0; i < stakeRecipients.length; i++) {
        address recipient = stakeRecipients[i];
        uint256 amount = stakeAmounts[i];

        if (stakingInfo[recipient].stakeAmount > 0) {
            revert StakerAlreadyExists();
        }

        // Create new staker instance and map it to the recipient address
        Staker memory newStaker = Staker(0, uint32(block.timestamp), amount, 0);
        stakingInfo[recipient] = newStaker;

        // Add recipient address to stakersAddresses array
        stakersAddresses.push(recipient);
    }
    }



    /**
    * @notice Unstakes the caller's tokens and calculates their rewards.
    * @dev This function allows a staker to withdraw their rewards and, if the staking period has ended (36 months or more), it also removes their stake entirely.
    *      The reward is calculated using the `calculateReward` function. If the staking period is complete, the staker is removed from the staking record.
    *
    * Requirements:
    * - The caller must have an active stake (`stakeAmount` > 0).
    * - The caller must not have been rewarded for more than 33 months.
    *
    * State Changes:
    * - Updates the `monthsRewarded` field for the staker in the `stakingInfo` mapping.
    * - Transfers the reward to the caller using the ERC-20 token.
    * - If the staking period is complete (36 months or more):
    *   - Removes the staker's address from the `stakersAddresses` array.
    *   - Deletes the staker's record in the `stakingInfo` mapping.
    *
    * Example Workflow:
    * 1. A staker calls `unstake` after 3 months, earning 3% of their staked amount per month as a reward.
    * 2. If 36 months have elapsed, their stake is fully withdrawn, and their records are removed.
    *
    * Edge Cases:
    * - If the staker has been rewarded for more than 33 months, the function reverts with `UserNoLongerStaking`.
    *
    * Events:
    * - (Optional) You could log events for staking removal or reward transfers for better tracking.
    */
    function unstake() public {
        // Ensure the staker exists
        if (stakingInfo[msg.sender].stakeAmount == 0) {
            revert StakerDoesNotExist(msg.sender);
        }
        if (stakingInfo[msg.sender].monthsRewarded >= 33){
            revert UserNoLongerStaking();
        }

        // Calculate the reward and updated the months rewarded
        (uint256 reward, uint256 monthsElapsed, uint256 rewardableMonths) = calculateReward(msg.sender);

        stakingInfo[msg.sender].monthsRewarded += uint8(rewardableMonths);
        stakingInfo[msg.sender].rewardsReceived += reward;

        // Transfer the reward and the stake back to the staker
        IERC20(token).transfer(msg.sender, reward);

        if (monthsElapsed >= 36){
            // Remove the staker from the stakersAddresses array
            for (uint256 i = 0; i < stakersAddresses.length; i++) {
                if (stakersAddresses[i] == msg.sender) {
                    stakersAddresses[i] = stakersAddresses[stakersAddresses.length - 1];
                    stakersAddresses.pop();
                    break;
                }
            }

            // Remove the staker from the stakingInfo mapping
            delete stakingInfo[msg.sender];

            emit StakeRemoved(msg.sender);
        }
    }


    /**
    * @notice Calculates the staking reward for a specific staker.
    * @dev The reward is computed as 3% of the staked amount for every full month elapsed since the stake was initiated + lock period of 3 months.
    *      A month is approximated as 30 days (2592000 seconds).
    * @param staker The address of the staker whose reward is to be calculated.
    * @return The calculated reward based on the stake duration and amount.
    *
    * Requirements:
    * - The staker must exist in the `stakingInfo` mapping.
    *
    * Example:
    * If a staker has a `stakeAmount` of 1000 tokens and 6 months have passed since `stakeInitTime`,
    * the reward will be calculated as 3% of 1000 (30 tokens) per month after the 3 month locking period, totaling 90 tokens.
    */
    function calculateReward(address staker) public view returns (uint256, uint256, uint256) {
        // Ensure the staker exists
        if (stakingInfo[staker].stakeAmount == 0) {
            revert StakerDoesNotExist(staker);
        }

        // Calculate the time difference in seconds
        uint256 timeElapsed = block.timestamp - stakingInfo[staker].stakeInitTime;

        // Calculate the number of months that have passed (30 days per month approx)
        uint256 monthsElapsed = timeElapsed / (30 days);

        if (monthsElapsed <= 3) {
            revert LockPeriodNotOver();
        }else if(monthsElapsed > 36){
            monthsElapsed = 36;
        }

        // Get the rewardable months (months after the lock period and not yet unstaked) and calculate the reward based on the monthly reward
        uint256 monthsRewarded = stakingInfo[staker].monthsRewarded; //months already rewarded
        uint256 rewardableMonths = monthsElapsed - LOCK_PERIOD_MONTHS - monthsRewarded; //months that can be rewarded
        uint256 reward = (stakingInfo[staker].stakeAmount * MONTHLY_REWARD_PERCENTAGE * rewardableMonths) / 100 ; //reward for the rewardable months

        // If the staker has been staking for 3 years, add the stake amount and the residual (what might be left from division rounding)
        //to the reward to complete the 100% reward
        if (monthsElapsed >= 36){
            uint256 residual = stakingInfo[staker].stakeAmount - reward - stakingInfo[staker].rewardsReceived; 
            reward = reward + stakingInfo[staker].stakeAmount + residual;
        }

        return (reward, monthsElapsed, rewardableMonths);
    }


    /**
    * @notice Retrieves details of all stakers.
    * @dev Loops through the `stakersAddresses` array to fetch staker details stored in the `stakingInfo` mapping.
    *      Returns the data as parallel arrays for addresses, stake initialization times, stake amounts, and months rewarded.
    * @return addresses Array of staker addresses.
    * @return stakeInitTimes Array of stake initialization timestamps corresponding to each staker.
    * @return stakeAmounts Array of stake amounts for each staker.
    * @return monthsRewardedArray Array of months rewarded for each staker.
    * @return rewardsReceived Array of rewards received for each staker.
    *
    * Requirements:
    * - The contract must have at least one staker stored in the `stakersAddresses` array.
    *
    * Example:
    * Assume the following data:
    * - `stakersAddresses` contains [0x123, 0x456].
    * - `stakingInfo[0x123]` has {monthsRewarded: 6, stakeInitTime: 1622505600, stakeAmount: 1000, rewardsReceived: 10}.
    * - `stakingInfo[0x456]` has {monthsRewarded: 3, stakeInitTime: 1625097600, stakeAmount: 500, rewardsReceived: 2}.
    *
    * The function will return:
    * - monthsRewardedArray: [6, 3].
    * - addresses: [0x123, 0x456].
    * - stakeInitTimes: [1622505600, 1625097600].
    * - stakeAmounts: [1000, 500].
    * - rewardsReceived: [10, 2].
    */
    function getAllStakerDetails() public view returns (address[] memory, uint8[] memory, uint64[] memory, uint256[] memory, uint256[] memory) {
        uint256 count = stakersAddresses.length;

        // Arrays to store the result
        address[] memory addresses = new address[](count);
        uint8[] memory monthsRewardedArray = new uint8[](count);
        uint64[] memory stakeInitTimes = new uint64[](count);
        uint256[] memory stakeAmounts = new uint256[](count);
        uint256[] memory rewardsReceived = new uint256[](count);

        // Loop through all staker addresses
        for (uint256 i = 0; i < count; i++) {
            address stakerAddress = stakersAddresses[i];
            Staker memory staker = stakingInfo[stakerAddress];

            // Store the staker's details in the respective arrays
            addresses[i] = stakerAddress;
            monthsRewardedArray[i] = staker.monthsRewarded;
            stakeInitTimes[i] = staker.stakeInitTime;
            stakeAmounts[i] = staker.stakeAmount;
            rewardsReceived[i] = staker.rewardsReceived;
        }

        // Return the arrays as the result
        return (addresses, monthsRewardedArray, stakeInitTimes, stakeAmounts, rewardsReceived);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function sumArray(uint[] memory array) public pure returns (uint) {
        uint sum = 0;
        for (uint i = 0; i < array.length; i++) {
            if (array[i] <= 1_000) {
                revert AmountMustBeBiggerThanaThousand();
            }
            sum += array[i];
        }
        return sum;
    }
    
    /*//////////////////////////////////////////////////////////////
                           TESTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Only used for foundry testing, no need to be audited since it will be deleted from the contract
    function getStakingInfo(address staker) external view returns (uint256, uint256, uint256, uint256) {
        return (stakingInfo[staker].stakeInitTime, stakingInfo[staker].stakeAmount, stakingInfo[staker].monthsRewarded, stakingInfo[staker].rewardsReceived);
    }
}