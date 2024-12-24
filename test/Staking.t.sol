// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {Staking} from "../src/Staking.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakingTest is Test {
    MockERC20 public mockERC20;
    Staking public staking;

    uint256 totalSupply = 72*10**18;
    uint256 _initBlockTime;

    address OwnerWallet = vm.addr(1001); //staking contract deployer and owner
    address MockERV20Creator = vm.addr(1002); //non-staker
    address Alice = vm.addr(1003); //staker
    address Bob = vm.addr(1004); //staker
    address Charlie = vm.addr(1005); //staker
    address Dylan = vm.addr(1006); //staker
    address Eckhart = vm.addr(1007); //staker
    address Frida = vm.addr(1008); //staker
    address Gabriella = vm.addr(1009); //staker
    address Hacker = vm.addr(1010); //non-staker

    function setUp() public {
        vm.startPrank(MockERV20Creator);
        mockERC20 = new MockERC20();
        mockERC20.mint(OwnerWallet, totalSupply);
        vm.stopPrank();

        vm.prank(OwnerWallet);
        staking = new Staking(address(mockERC20));
        
    }

    /* Test stake:
    *   1. staker is not the owner
    *   2. stake amount is greater than 0
    *   3. stake is successful
    *   4. staker does not already have an active stake 
    */
    function testSingleStake() public {
        vm.prank(OwnerWallet);
        mockERC20.approve(address(staking), 2*(10+20)*10**18);

        // 1. staker is not the owner
        //      1.a. staker is the stake address
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(Alice)
            )
        );
        vm.prank(Alice);
        staking.stake(Alice, 10*10**3);

        //      1.b. staker is a random address
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(Hacker)
            )
        );
        vm.prank(Hacker);
        staking.stake(Alice, 10*10**3);


        // 2. stake amount is greater than 0
        vm.expectRevert(Staking.AmountMustBeBiggerThanaThousand.selector);
        vm.prank(OwnerWallet);
        staking.stake(Alice, 0);


        // 3. stake is successful
        vm.prank(OwnerWallet);
        staking.stake(Alice, 10*10**3);
        (uint256 stakeInitTime, uint256 stakeAmount, uint256 monthsRewarded, uint256 rewardsReceived) = staking.getStakingInfo(Alice);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, 10*10**3);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        // 4. staker does not already have an active stake
        vm.expectRevert(Staking.StakerAlreadyExists.selector);
        vm.prank(OwnerWallet);
        staking.stake(Alice, 10*10**3);

        // stake to Bob as well, 10 days latter
        vm.warp(block.timestamp + 10 days);
        vm.prank(OwnerWallet);
        staking.stake(Bob, 20*10**18);
        (stakeInitTime, stakeAmount, monthsRewarded, rewardsReceived) = staking.getStakingInfo(Bob);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, 20*10**18);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

    }

    /* Test stake:
    *   Phase 1. staker is not the owner
    *   Phase 2. stake amount is greater than 0
    *   Phase 3. stake is successful
    *   Phase 4. staker does not already have an active stake 
    *   Phase 5. test single stake after the successful multiple stake
    *   Phase 6. test multiple stake again
    *   Phase 7. test unstake and calc rewards by calling the testCalcRewardandUnstakeandUnstake function
    */
    function testMultipleStake(uint256 amount0, uint256 amount1, 
                                uint256 amount2, uint256 amount3, 
                                uint256 amount4, uint256 amount5, 
                                uint256 amount6) public {

        // Fuzz testing variables. The amount should be greater than 1000 and less than half of the total supply (split between the 7 stakers)
        uint256 maxAMountPerStake = totalSupply/2/7;
        vm.assume(amount0 > 1000 && amount0 < maxAMountPerStake);
        vm.assume(amount1 > 1000 && amount1 < maxAMountPerStake);
        vm.assume(amount2 > 1000 && amount2 < maxAMountPerStake);
        vm.assume(amount3 > 1000 && amount3 < maxAMountPerStake);
        vm.assume(amount4 > 1000 && amount4 < maxAMountPerStake);
        vm.assume(amount5 > 1000 && amount5 < maxAMountPerStake);
        vm.assume(amount6 > 1000 && amount6 < maxAMountPerStake);

        // Approve the staking contract to get the tokens from the Owner
        vm.prank(OwnerWallet);
        mockERC20.approve(address(staking), 2*(amount0+amount1+amount2+amount3)*10**18);

        // Phase 1. staker is not the owner
        address[] memory stakerAddresses = new address[](4);
        stakerAddresses[0] = address(Alice);
        stakerAddresses[1] = address(Bob);
        stakerAddresses[2] = address(Charlie);
        stakerAddresses[3] = address(Dylan);  
        uint256[] memory stakeAmounts = new uint256[](4);
        stakeAmounts[0] = amount0;
        stakeAmounts[1] =  amount1;
        stakeAmounts[2] =  amount2;
        stakeAmounts[3] =  amount3;

        //      1.a. staker is one of the stake address
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(Alice)
            )
        );
        vm.prank(Alice);
        staking.stakeMultiple(stakerAddresses, stakeAmounts);

        //      1.b. staker is a random address
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(Hacker)
            )
        );
        vm.prank(Hacker);
        staking.stakeMultiple(stakerAddresses, stakeAmounts);


        // Phase 2. stake amount is less than 1000
        stakeAmounts[2] =  10;

        vm.expectRevert(Staking.AmountMustBeBiggerThanaThousand.selector);
        vm.prank(OwnerWallet);
        staking.stakeMultiple(stakerAddresses, stakeAmounts);

        // Save the block before any staking for the testing of the rewards
        _initBlockTime = block.timestamp;

        // Phase 3. stake is successful
        stakeAmounts[2] =  amount2;

        vm.prank(OwnerWallet);
        staking.stakeMultiple(stakerAddresses, stakeAmounts);

        (uint256 stakeInitTime, uint256 stakeAmount, uint256 monthsRewarded, uint256 rewardsReceived) = staking.getStakingInfo(Alice);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, amount0);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        (stakeInitTime, stakeAmount, monthsRewarded, rewardsReceived) = staking.getStakingInfo(Bob);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, amount1);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        (stakeInitTime, stakeAmount, monthsRewarded, rewardsReceived) = staking.getStakingInfo(Charlie);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, amount2);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        (stakeInitTime, stakeAmount, monthsRewarded, rewardsReceived) = staking.getStakingInfo(Dylan);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, amount3);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        // Phase 4. staker does not already have an active stake
        address[] memory secondStakerAddresses = new address[](3);
        secondStakerAddresses[0] = address(Eckhart);
        secondStakerAddresses[1] = address(Bob);
        secondStakerAddresses[2] = address(Frida);
        uint256[] memory secondStakeAmounts = new uint256[](3);
        secondStakeAmounts[0] = amount4;
        secondStakeAmounts[1] =  amount4;
        secondStakeAmounts[2] =  amount5;

        vm.startPrank(OwnerWallet);
        mockERC20.approve(address(staking), 2*(2*amount4+amount5)*10**18); //approve more tokens
        vm.expectRevert(Staking.StakerAlreadyExists.selector);
        staking.stakeMultiple(secondStakerAddresses, secondStakeAmounts);
        vm.stopPrank();

        // Phase 5. test single stake after the multiple - stake to Eckhart as well, 20 days latter
        vm.warp(block.timestamp + 30 days);

        vm.prank(OwnerWallet);
        staking.stake(Eckhart, amount4);

        (stakeInitTime, stakeAmount, monthsRewarded, rewardsReceived) = staking.getStakingInfo(Eckhart);
        assertEq(stakeInitTime, block.timestamp);
        assertEq(stakeAmount, amount4);
        assertEq(monthsRewarded, 0);
        assertEq(rewardsReceived, 0);

        // Phase 6. test multiple stake again
        address[] memory thirdStakerAddresses = new address[](2);
        thirdStakerAddresses[0] = address(Frida);
        thirdStakerAddresses[1] = address(Gabriella);
        uint256[] memory thirdStakeAmounts = new uint256[](2);
        thirdStakeAmounts[0] = amount5;
        thirdStakeAmounts[1] =  amount6;


        vm.startPrank(OwnerWallet);
        mockERC20.approve(address(staking), 2*(amount5+amount6)*10**18);
        staking.stakeMultiple(thirdStakerAddresses, thirdStakeAmounts);
        vm.stopPrank();


        // Test the calc rewards
        testCalcRewardandUnstake( amount0, amount1, amount2, amount3, amount4, amount5, amount6);

    }

    /* Test calc rewards and unstake:
    * Phase 1. 1 month passed for the first 4 stakers and 0 for the other 3
    * Phase 2. 120 days (4 months) have passed since the first 4 stakes and 90 for the other 3
    * Phase 3. 210 days (7 months) have passed since the first 4 stakes and 180 for the other 3
    * Phase 4. 330 days (11 months) have passed since the first 4 stakes and 300 (10 months) for the other 3
    * Phase 5. 1080 days (36 months) have passed since the first 4 stakes and 1050 (35 months) for the other 3
    * Phase 6. 1110 days (37 months) have passed since the first 4 stakes and 1080 (36 months) for the other 3
    */
    function testCalcRewardandUnstake(uint256 amount0, uint256 amount1, 
                                        uint256 amount2, uint256 amount3, 
                                        uint256 amount4, uint256 amount5, 
                                        uint256 amount6) 
                                        internal {

        // Get back the block time before the staking
        uint256 initBlockTime = _initBlockTime;

        // Establish stakers and amounts
        address[7] memory stakerAddresses = [Alice, Bob, Charlie, Dylan, Eckhart, Frida, Gabriella];
        uint256[7] memory stakerAmounts = [amount0, amount1, amount2, amount3, amount4, amount5, amount6];
        (uint256 reward, uint256 monthsElapsed, uint256 rewardableMonths) = (0, 0, 0);

        // Phase 1:
        // - 30 days have passed since the first 4 stakes and 0 for the other 3
        // - Since the 3 months lock period is not over, no rewards can be claimed
        vm.warp(initBlockTime + 1*30 days);// simulate a month since the first stakes
        for(uint i = 0; i < stakerAddresses.length; i++){
            vm.expectRevert(Staking.LockPeriodNotOver.selector);
            (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
        }

        // Phase 2: 
        // - 120 days (4 months) have passed since the first 4 stakes and 90 for the other 3
        // - The first 4 stakers will be ale to claim 1 month of rewards
        // - The last 3 just finished the lock period, so no month to claim
        vm.warp(initBlockTime + 4*30 days);
        for(uint i = 0; i < stakerAddresses.length; i++){
            if(i>=4){
                vm.expectRevert(Staking.LockPeriodNotOver.selector);
                (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
            }else{
                (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
                assertEq(4, monthsElapsed);
                assertEq(1, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);
            }
        }

        // Phase 3: 
        // - 210 days (7 months) have passed since the first 4 stakes and 180 for the other 3
        // - The first 4 stakers will be ale to claim 4 month of rewards and they will claim them
        // - The last 3 stakers will be ale to claim their first 3 month of rewards
        vm.warp(initBlockTime + 7*30 days);
        for(uint i = 0; i < stakerAddresses.length; i++){
            (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
            if(i>=4){
                assertEq(6, monthsElapsed);
                assertEq(3, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);
            }else{
                assertEq(7, monthsElapsed);
                assertEq(4, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);

                vm.prank(stakerAddresses[i]);
                staking.unstake();

                assertEq(mockERC20.balanceOf(stakerAddresses[i]), reward);
            }
        }

        // Phase 4: 
        // - 330 days (11 months) have passed since the first 4 stakes and 300 (10 months) for the other 3
        // - The first 4 stakers will be ale to claim 4 more month of rewards (they already claimed 4, so 8) and they will claim them
        // - The last 3 stakers will be ale to claim their first 7 month of rewards
        vm.warp(initBlockTime + 11*30 days);
        for(uint i = 0; i < stakerAddresses.length; i++){
            (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
            if(i>=4){
                assertEq(10, monthsElapsed);
                assertEq(7, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);
            }else{
                assertEq(11, monthsElapsed);
                assertEq(4, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);

                vm.prank(stakerAddresses[i]);
                staking.unstake();
            }
        }

        // Phase 5: 
        // - 1080 days (36 months) have passed since the first 4 stakes and 1050 (35 months) for the other 3
        // - The first 4 stakers will be ale to claim 25 more months and their full initial stake
        // - The last 3 stakers will be ale to claim their 32 months of rewards
        vm.warp(initBlockTime + 36*30 days);
        for(uint i = 0; i < stakerAddresses.length; i++){
            (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
            if(i>=4){
                assertEq(35, monthsElapsed);
                assertEq(32, rewardableMonths);
                assertEq(reward, 3*stakerAmounts[i]*rewardableMonths/100);

                vm.prank(stakerAddresses[i]);
                staking.unstake();
            }else{
                assertEq(36, monthsElapsed);
                assertEq(25, rewardableMonths);

                vm.prank(stakerAddresses[i]);
                staking.unstake();
            }
        }

        // Phase 6: 
        // - 1200 days (40 months) have passed since the first 4 stakes and 1170 (39 months) for the other 3
        // - The first 4 stakers are no longer in the mappings so it will through an error
        // - The last 3 stakers will be ale to claim 1 month of rewards and their initial stake
        vm.warp(initBlockTime + 40*30 days);
        for(uint i = 0; i < stakerAddresses.length; i++){
            
            if(i>=4){
                (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
                assertEq(36, monthsElapsed);
                assertEq(1, rewardableMonths);

                vm.prank(stakerAddresses[i]);
                staking.unstake();
            }else{

                vm.expectRevert(
                    abi.encodeWithSelector(
                        Staking.StakerDoesNotExist.selector,
                        address(stakerAddresses[i])
                    )
                );
                (reward, monthsElapsed, rewardableMonths) = staking.calculateReward(stakerAddresses[i]);
            }
        }

        // Verify final balances
        assertEq(mockERC20.balanceOf(Alice), 2*stakerAmounts[0]);
        assertEq(mockERC20.balanceOf(Bob), 2*stakerAmounts[1]);
        assertEq(mockERC20.balanceOf(Charlie), 2*stakerAmounts[2]);
        assertEq(mockERC20.balanceOf(Dylan), 2*stakerAmounts[3]);
        assertEq(mockERC20.balanceOf(Eckhart), 2*stakerAmounts[4]);
        assertEq(mockERC20.balanceOf(Frida), 2*stakerAmounts[5]);
        assertEq(mockERC20.balanceOf(Gabriella), 2*stakerAmounts[6]);
        assertEq(mockERC20.balanceOf(address(staking)), 0);
    }

}
