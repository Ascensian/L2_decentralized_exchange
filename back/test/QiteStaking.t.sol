// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/QiteStaking.sol";
import "../src/QiteRandomToken.sol";

contract QiteStakingTest is Test {
    QiteStaking staking;
    QiteRandomToken token;
    address admin = address(1);
    address user = address(2);
    uint256 rewardRate = 1e18;

    function setUp() public {
        token = new QiteRandomToken("StakingToken", "STK");
        staking = new QiteStaking(address(token), rewardRate, admin);

        vm.prank(admin);
        staking.grantRole(staking.USER_ROLE(), user);
    }

    function testStake() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(admin);
        token.mint(user, amount);

        vm.startPrank(user);
        token.approve(address(staking), amount);
        staking.stake(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(user), amount);
    }

    function testUnstake() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(admin);
        token.mint(user, amount);

        vm.startPrank(user);
        token.approve(address(staking), amount);
        staking.stake(amount);
        staking.unstake(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(user), 0);
    }

    function testGetReward() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(admin);
        token.mint(user, amount);

        vm.startPrank(user);
        token.approve(address(staking), amount);
        staking.stake(amount);

        vm.warp(block.timestamp + 1 days);
        staking.getReward();
        vm.stopPrank();

        uint256 expectedReward = 1 days * rewardRate;
        assertEq(token.balanceOf(user), expectedReward);
    }
}
