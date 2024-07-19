// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/QiteLiquidityToken.sol";

contract QiteLiquidityTokenTest is Test {
    QiteLiquidityToken public liquidityToken;
    address public admin = address(this);
    address public user = address(0x123);

    function setUp() public {
        liquidityToken = new QiteLiquidityToken("LiquidityToken", "LTK");
        liquidityToken.grantRole(liquidityToken.DEFAULT_ADMIN_ROLE(), admin);
    }

    function testMint() public {
        liquidityToken.mint(user, 1000);
        assertEq(liquidityToken.balanceOf(user), 1000);
    }

    function testBurn() public {
        liquidityToken.mint(user, 1000);
        liquidityToken.burn(user, 500);
        assertEq(liquidityToken.balanceOf(user), 500);
    }
}
