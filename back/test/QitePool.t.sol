// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../src/QitePool.sol";
import "../src/QiteLiquidityToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract QitePoolTest is Test {
    QitePool public pool;
    QiteLiquidityToken public liquidityToken;
    ERC20Mock public token1;
    ERC20Mock public token2;
    AggregatorV3Interface public priceFeed1;
    AggregatorV3Interface public priceFeed2;

    address public user = address(0x123);
    address public admin = address(this);

    function setUp() public {
        token1 = new ERC20Mock("Token1", "TK1");
        token2 = new ERC20Mock("Token2", "TK2");
        priceFeed1 = new MockAggregator();
        priceFeed2 = new MockAggregator();
        liquidityToken = new QiteLiquidityToken("LiquidityToken", "LTK");
        pool = new QitePool(address(token1), address(token2), "LiquidityToken", "LTK", address(priceFeed1), address(priceFeed2));

        // Assurez-vous que l'adresse `this` (le contrat de test) a le rôle `ADMIN_ROLE` et `USER_ROLE`
        vm.prank(admin);
        pool.grantRole(pool.ADMIN_ROLE(), admin);
        vm.prank(admin);
        pool.grantRole(pool.USER_ROLE(), user);
    }

    function testAddLiquidity() public {
        token1.mint(user, 1000);
        token2.mint(user, 1000);

        vm.startPrank(user);
        token1.approve(address(pool), 1000);
        token2.approve(address(pool), 1000);
        pool.addLiquidity(500, 500);
        vm.stopPrank();

        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, 500);
        assertEq(reserve2, 500);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();

        vm.startPrank(user);
        uint256 liquidity = liquidityToken.balanceOf(user);
        pool.removeLiquidity(liquidity);
        vm.stopPrank();

        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, 0);
        assertEq(reserve2, 0);
    }

    function testSwapTokens() public {
        testAddLiquidity();

        token1.mint(user, 1000);

        vm.startPrank(user);
        token1.approve(address(pool), 1000);
        pool.swapTokens(address(token1), address(token2), 100);
        vm.stopPrank();

        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assert(reserve1 > 500);
        assert(reserve2 < 500);
    }

    function testSetFeeRate() public {
        vm.prank(admin);
        pool.setFeeRate(50);
        assertEq(pool.getFeeRate(), 50);
    }

    function testBanUser() public {
        vm.prank(admin);
        pool.banUser(user);
        assert(!pool.hasRole(pool.USER_ROLE(), user));
    }

    function testRegisterUser() public {
        address newUser = address(0x456);
        vm.prank(admin);
        pool.registerUser(newUser);
        assert(pool.hasRole(pool.USER_ROLE(), newUser));
    }
}

contract MockAggregator is AggregatorV3Interface {
    function decimals() external pure override returns (uint8) { return 18; }
    function description() external pure override returns (string memory) { return "Mock"; }
    function version() external pure override returns (uint256) { return 1; }
    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) { return (0, 1e18, 0, 0, 0); }
    function latestRoundData() external pure override returns (uint80, int256, uint256, uint256, uint80) { return (0, 1e18, 0, 0, 0); }
}
