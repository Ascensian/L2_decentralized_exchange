// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing necessary libraries and contracts
import "../lib/forge-std/src/Test.sol";
import "../src/Pool.sol";
import "../src/LiquidityToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) 
        ERC20(name, symbol) 
    {
        _mint(msg.sender, initialSupply);
    }
}

// Mock AggregatorV3Interface for testing
contract MockAggregator is AggregatorV3Interface {
    int256 private _price;
    
    function setPrice(int256 price) external {
        _price = price;
    }

    function latestRoundData() 
        external 
        view 
        override 
        returns (
            uint80, 
            int256 answer, 
            uint256, 
            uint256, 
            uint80
        ) 
    {
        return (0, _price, 0, 0, 0);
    }

    function decimals() external view override returns (uint8) { return 18; }
    function description() external view override returns (string memory) { return ""; }
    function version() external view override returns (uint256) { return 0; }
    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 0, 0, 0, 0);
    }
}

// The test contract inherits from Test and AccessControl
contract PoolTest is Test, AccessControl {
    Pool public pool;
    MockERC20 public token1;
    MockERC20 public token2;
    LiquidityToken public liquidityToken;
    MockAggregator public aggregator1;
    MockAggregator public aggregator2;
    address public user = address(1);
    address public admin = address(2);

    uint256 initialTokenSupply = 1_000_000 ether; // Initial supply for mock tokens

    // Internal function to grant roles using AccessControl's _grantRole
    function _setupRoles() internal {
        _grantRole(pool.USER_ROLE(), user);
        _grantRole(pool.ADMIN_ROLE(), admin);
    }

    function setUp() public {
        // Deploy mock tokens
        token1 = new MockERC20("Token1", "TK1", initialTokenSupply);
        token2 = new MockERC20("Token2", "TK2", initialTokenSupply);

        // Deploy mock aggregators with a price
        aggregator1 = new MockAggregator();
        aggregator2 = new MockAggregator();
        aggregator1.setPrice(1 ether); // 1 TK1 = 1 USD
        aggregator2.setPrice(2 ether); // 1 TK2 = 2 USD

        // Deploy the Pool contract
        pool = new Pool(
            address(token1), 
            address(token2), 
            "LiquidityToken", 
            "LQT", 
            address(aggregator1), 
            address(aggregator2)
        );

        // Grant roles
        _setupRoles();

        // Transfer tokens to user for testing
        token1.transfer(user, 10_000 ether);
        token2.transfer(user, 10_000 ether);

        // Approve pool contract to spend user's tokens
        vm.startPrank(user);
        token1.approve(address(pool), type(uint256).max);
        token2.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testAddLiquidity() public {
        vm.startPrank(user);

        uint256 amountToken1 = 1000 ether;
        uint256 amountToken2 = 500 ether;

        pool.addLiquidity(amountToken1, amountToken2);

        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, amountToken1, "Reserve1 should match amountToken1");
        assertEq(reserve2, amountToken2, "Reserve2 should match amountToken2");

        uint256 liquidityBalance = pool.liquidityToken().balanceOf(user);
        assertGt(liquidityBalance, 0, "Liquidity token balance should be greater than 0");

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        vm.startPrank(user);

        uint256 amountToken1 = 1000 ether;
        uint256 amountToken2 = 500 ether;

        pool.addLiquidity(amountToken1, amountToken2);

        uint256 liquidityBalanceBefore = pool.liquidityToken().balanceOf(user);

        pool.removeLiquidity(liquidityBalanceBefore);

        (uint256 reserve1, uint256 reserve2) = pool.getReserves();
        assertEq(reserve1, 0, "Reserve1 should be zero after removing liquidity");
        assertEq(reserve2, 0, "Reserve2 should be zero after removing liquidity");

        uint256 liquidityBalanceAfter = pool.liquidityToken().balanceOf(user);
        assertEq(liquidityBalanceAfter, 0, "Liquidity token balance should be zero after removing liquidity");

        vm.stopPrank();
    }

    function testSwapTokens() public {
        vm.startPrank(user);

        uint256 amountToken1 = 1000 ether;
        uint256 amountToken2 = 500 ether;
        
        // Add initial liquidity
        pool.addLiquidity(amountToken1, amountToken2);

        uint256 amountIn = 100 ether;
        uint256 balanceToken2Before = token2.balanceOf(user);

        pool.swapTokens(address(token1), address(token2), amountIn);

        uint256 balanceToken2After = token2.balanceOf(user);
        assertGt(balanceToken2After, balanceToken2Before, "User should have more token2 after swap");

        vm.stopPrank();
    }

    function testAccessControl() public {
        vm.startPrank(user);

        // User cannot set fee rate
        vm.expectRevert("Caller is not an admin");
        pool.setFeeRate(100);

        vm.stopPrank();

        vm.startPrank(admin);

        // Admin can set fee rate
        pool.setFeeRate(100);
        assertEq(pool.getFeeRate(), 100, "Fee rate should be set by admin");

        // Admin can ban user
        pool.banUser(user);
        vm.expectRevert("Caller is not a registered user");
        vm.prank(user);
        pool.addLiquidity(1000 ether, 500 ether);

        vm.stopPrank();
    }
}
