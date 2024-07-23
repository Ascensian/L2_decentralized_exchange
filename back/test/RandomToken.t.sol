// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/RandomToken.sol";

contract RandomTokenTest is Test {
    RandomToken token;

    function setUp() public {
        token = new RandomToken("TestToken", "TT");
    }

    function testInitialSupply() public view {
        uint256 expectedSupply = 1000 * 10 ** token.decimals();
        assertEq(token.totalSupply(), expectedSupply);
    }

    function testMint() public {
        address user = address(0x123);
        uint256 amountToMint = 500;

        token.mint(user, amountToMint);
        
        assertEq(token.balanceOf(user), amountToMint);
    }
}
