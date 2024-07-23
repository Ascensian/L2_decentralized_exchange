// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import necessary libraries and contracts
import "../lib/forge-std/src/Test.sol";
import "../src/Swap.sol";
import "../src/Pool.sol";
import "../src/LiquidityToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
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
contract SwapTest is Test, AccessControl {
    Swap public swap;
    MockERC20 public token1;
    MockERC20 public token2;
    MockAggregator public aggregator1;
    MockAggregator public aggregator2;
    address public user = address(1);
    address public admin = address(2);

    uint256 initialTokenSupply = 1_000_000 ether; // Initial supply for mock tokens

    // Internal function to grant roles using AccessControl's _grantRole
    function _setupRoles() internal {
        _grantRole(swap.USER_ROLE(), user);
        _grantRole(swap.ADMIN_ROLE(), admin);
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

        // Deploy the Swap contract
        swap = new Swap();

        // Grant roles
        _setupRoles();

        // Transfer tokens to user for testing
        token1.transfer(user, 10_000 ether);
        token2.transfer(user, 10_000 ether);

        // Approve swap contract to spend user's tokens
        vm.startPrank(user);
        token1.approve(address(swap), type(uint256).max);
        token2.approve(address(swap), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePairs() public {
        vm.startPrank(admin);

        address poolAddress = swap.createPairs(
            address(token1), 
            address(token2), 
            "Token1", 
            "Token2", 
            address(aggregator1), 
            address(aggregator2)
        );

        assertTrue(poolAddress != address(0), "Pool address should not be zero");
        assertEq(swap.allPairsLength(), 1, "There should be one pair created");

        vm.stopPrank();
    }

    function testSetPlatformFeeRate() public {
        vm.startPrank(admin);

        address poolAddress = swap.createPairs(
            address(token1), 
            address(token2), 
            "Token1", 
            "Token2", 
            address(aggregator1), 
            address(aggregator2)
        );

        swap.setPlatformFeeRate(address(token1), address(token2), 100);

        Pool pool = Pool(poolAddress);
        assertEq(pool.getFeeRate(), 100, "Fee rate should be set to 100");

        vm.stopPrank();
    }

    function testBanUser() public {
        vm.startPrank(admin);

        address poolAddress = swap.createPairs(
            address(token1), 
            address(token2), 
            "Token1", 
            "Token2", 
            address(aggregator1), 
            address(aggregator2)
        );

        swap.banUser(address(token1), address(token2), user);

        Pool pool = Pool(poolAddress);
        vm.expectRevert("Caller is not a registered user");
        vm.prank(user);
        pool.addLiquidity(1000 ether, 500 ether);

        vm.stopPrank();
    }

    function testGetPlatformStatistics() public {
        vm.startPrank(admin);

        address poolAddress = swap.createPairs(
            address(token1), 
            address(token2), 
            "Token1", 
            "Token2", 
            address(aggregator1), 
            address(aggregator2)
        );

        vm.prank(user);
        Pool pool = Pool(poolAddress);
        pool.addLiquidity(1000 ether, 500 ether);

        (uint256 reserve1, uint256 reserve2, uint256 feeRate, uint256 collectedFees) = swap.getPlatformStatistics(address(token1), address(token2));

        assertEq(reserve1, 1000 ether, "Reserve1 should match added liquidity");
        assertEq(reserve2, 500 ether, "Reserve2 should match added liquidity");
        assertEq(feeRate, 0, "Initial fee rate should be 0");
        assertEq(collectedFees, 0, "Collected fees should be 0");

        vm.stopPrank();
    }
}
