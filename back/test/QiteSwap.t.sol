// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/QiteSwap.sol";
import "../src/QitePool.sol";
import "../src/QiteStaking.sol";
import "../src/QiteRandomToken.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract QiteSwapTest is Test, AccessControl {
    QiteSwap swap;
    QiteStaking staking;
    QiteRandomToken token1;
    QiteRandomToken token2;
    QiteRandomToken liquidityToken;
    address admin = address(this);
    address user = address(2);

    function setUp() public {
        token1 = new QiteRandomToken("Token1", "T1");
        token2 = new QiteRandomToken("Token2", "T2");
        staking = new QiteStaking(address(token1), 1e18, admin);

        vm.prank(admin);
        swap = new QiteSwap(address(staking));

        vm.prank(admin);
        _grantRole(swap.ADMIN_ROLE(), admin);
        vm.prank(admin);
        _grantRole(swap.USER_ROLE(), user);
    }

    function testCreatePairs() public {
    address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

    assertEq(swap.allPairsLength(), 1);
    QitePool createdPair = QitePool(swap.getPair(address(token1), address(token2)));
    assertEq(address(createdPair), pair);
    }

    function testStakeLiquidityTokens() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(admin);
        address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

        QitePool pool = QitePool(pair);
        vm.prank(admin);
        pool.liquidityToken().mint(user, amount);

        vm.startPrank(user);
        pool.liquidityToken().approve(address(swap), amount);
        swap.stakeLiquidityTokens(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(user), amount);
    }

    function testUnstakeLiquidityTokens() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(admin);
        address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

        QitePool pool = QitePool(pair);
        vm.prank(admin);
        pool.liquidityToken().mint(user, amount);

        vm.startPrank(user);
        pool.liquidityToken().approve(address(swap), amount);
        swap.stakeLiquidityTokens(amount);
        swap.unstakeLiquidityTokens(amount);
        vm.stopPrank();

        assertEq(staking.stakedBalance(user), 0);
    }

    function testSetPlatformFeeRate() public {
        uint256 feeRate = 5;
        vm.prank(admin);
        address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

        vm.prank(admin);
        swap.setPlatformFeeRate(address(token1), address(token2), feeRate);

        QitePool pool = QitePool(pair);
        assertEq(pool.getFeeRate(), feeRate);
    }

    function testBanUser() public {
    vm.prank(admin);
    address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

    vm.prank(admin);
    swap.banUser(address(token1), address(token2), user);

    QitePool pool = QitePool(pair);

    assertFalse(pool.hasRole(pool.USER_ROLE(), user));
}

    function testGetPlatformStatistics() public {
        vm.prank(admin);
        address pair = swap.createPairs(address(token1), address(token2), "T1", "T2", address(0), address(0));

        QitePool pool = QitePool(pair);
        uint256 amountToken1 = 1000 * 10**18;
        uint256 amountToken2 = 2000 * 10**18;

        vm.prank(admin);
        token1.mint(user, amountToken1);
        vm.prank(admin);
        token2.mint(user, amountToken2);

        vm.startPrank(user);
        token1.approve(address(pool), amountToken1);
        token2.approve(address(pool), amountToken2);
        pool.addLiquidity(amountToken1, amountToken2);
        vm.stopPrank();

        (uint256 reserve1, uint256 reserve2, uint256 feeRate, uint256 collectedFees) = swap.getPlatformStatistics(address(token1), address(token2));
        assertEq(reserve1, amountToken1);
        assertEq(reserve2, amountToken2);
        assertEq(feeRate, pool.getFeeRate());
        assertEq(collectedFees, 0);
    }
}
