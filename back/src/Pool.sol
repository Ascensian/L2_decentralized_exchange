// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LiquidityToken.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";



contract Pool is AccessControl {
    using Math for uint;

    address public token1;
    address public token2;
    uint256 public reserve1;
    uint256 public reserve2;
    uint256 public constantK;
    LiquidityToken public liquidityToken;
    mapping(address => uint256) public collectedFees;

    uint256 public feeRate;

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Chainlink variables
    AggregatorV3Interface internal priceFeed1;
    AggregatorV3Interface internal priceFeed2;

    event Swap(
        address indexed sender,
        uint256 amountIn,
        uint256 amountOut,
        address tokenFrom,
        address tokenTo
    );

    event FeesCollected(
        address indexed collector,
        uint256 amount,
        address token
    );

    event UserRegistered(
        address indexed user
    );

    event UserBanned(
        address indexed user
    );

    constructor(address _token1, address _token2, string memory _liquidityTokenName, string memory _liquidityTokenSymbol, address _priceFeed1, address _priceFeed2) {
        _grantRole(ADMIN_ROLE, msg.sender);

        token1 = _token1;
        token2 = _token2;
        liquidityToken = new LiquidityToken(_liquidityTokenName, _liquidityTokenSymbol);

        // Initialize Chainlink price feeds
        priceFeed1 = AggregatorV3Interface(_priceFeed1);
        priceFeed2 = AggregatorV3Interface(_priceFeed2);
    }

    function getLatestPrice(address token) public view returns (int) {
        AggregatorV3Interface priceFeed = (token == token1) ? priceFeed1 : priceFeed2;
        (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        return price;
    }

    function addLiquidity(uint256 amountToken1, uint256 amountToken2) external {
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        // calculate the number of liquidity token to send to liquidity provider
        uint256 liquidity;
        uint256 totalSupplyLiquidityToken = liquidityToken.totalSupply();
        if(totalSupplyLiquidityToken == 0){
            liquidity = (amountToken1 * amountToken2).sqrt();
        }else{
            liquidity = (amountToken1 * totalSupplyLiquidityToken / reserve1).min(amountToken2 * totalSupplyLiquidityToken / reserve2);
        }
        // Mint this amount to the liquidity provider
        liquidityToken.mint(msg.sender, liquidity);
        // Transfer token1 and token2 into the liquidity pool
        require(IERC20(token1).transferFrom(msg.sender, address(this), amountToken1), "Transfer of token1 failed");
        require(IERC20(token2).transferFrom(msg.sender, address(this), amountToken2), "Transfer of token2 failed");
        // Update the reserves
        reserve1 += amountToken1;
        reserve2 += amountToken2;
        // Update constant k
        _updateConstantFormula();
        // add events
    }

    function removeLiquidity(uint256 amountOfLiquidity) external {
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        uint256 totalSupplyOfLT = liquidityToken.totalSupply();
        // checks
        uint256 balanceOfSender = liquidityToken.balanceOf(msg.sender);
        require(amountOfLiquidity <= balanceOfSender, "You don't have enough liquidity token");
        // Burn token of liquidity
        liquidityToken.burn(msg.sender, amountOfLiquidity);
        // Transfer back token1 and token2 to sender
        uint256 amountToken1 = (reserve1 * amountOfLiquidity) / totalSupplyOfLT;
        uint256 amountToken2 = (reserve2 * amountOfLiquidity) / totalSupplyOfLT;
        require(IERC20(token1).transfer(msg.sender, amountToken1), "Transfer of token1 failed");
        require(IERC20(token2).transfer(msg.sender, amountToken2), "Transfer of token2 failed");
        // Update the reserves
        reserve1 -= amountToken1;
        reserve2 -= amountToken2;
        // Update constant k
        _updateConstantFormula();
        // add events
    }

    function swapTokens(address fromToken, address toToken, uint256 amountIn) external {
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        // checks
        require(amountIn > 0, "Amount must be greater than 0");
        require((fromToken == token1 && toToken == token2) || (fromToken == token2 && toToken == token1), "From and to token are not token of the pool");
        IERC20 fromTokenContract = IERC20(fromToken);
        IERC20 toTokenContract = IERC20(toToken);
        require(fromTokenContract.balanceOf(msg.sender) >= amountIn, "Insufficient balance of tokenFrom");
        // calculate expected amount and compare to amount Out
        uint256 expectedAmount;
        uint256 fee = (amountIn * feeRate) / 10000;
        uint256 amountInAfterFee = amountIn - fee;
        collectedFees[fromToken] += fee;
        // 10 * 10 = 100
        // reserve1 * reserve2 = constantK
        // (reserve1 + amountIn)*(reserve2 - expectedAmountOut) = constantK
        // reserve2-expectedAmountOut = constantK/ (reserve1+amountIn) 
        // expecteAmountOut = reserve2 - constantK / (reserve1+amountIn)
        // Get the latest price from Chainlink oracle
        int priceFromToken = getLatestPrice(fromToken);
        int priceToToken = getLatestPrice(toToken);

        require(priceFromToken > 0 && priceToToken > 0, "Invalid token prices");

        uint256 amountOutFromOracle = uint256((amountInAfterFee * uint256(priceFromToken)) / uint256(priceToToken));

        // Check if the swap maintains the constant product formula
        if(fromToken == token1){
            expectedAmount = reserve2 - constantK / (reserve1 + amountInAfterFee);
        }else{
            expectedAmount = reserve1 - constantK / (reserve2 + amountInAfterFee);
        }

        uint256 finalAmountOut = amountOutFromOracle < expectedAmount ? amountOutFromOracle : expectedAmount;

        require(toTokenContract.balanceOf(address(this)) >= finalAmountOut, "Insufficient balance of tokenTo");

        // Perform the swap
        require(fromTokenContract.transferFrom(msg.sender, address(this), amountIn), "Transfer of fromToken failed");
        require(toTokenContract.transfer(msg.sender, finalAmountOut), "Transfer of toToken failed");
        // update the reserves
        if(fromToken == token1){
            reserve1 += amountInAfterFee;
            reserve2 -= finalAmountOut;
        }else{
            reserve1 -= finalAmountOut;
            reserve2 += amountInAfterFee;
        }
        // Check swap is maintaining the constant formula
        require(reserve1*reserve2 <= constantK, "Swap does not preserve constant formula");
        // Update constant k
        _updateConstantFormula();
        // add events
        emit Swap(msg.sender, amountIn, finalAmountOut, fromToken, toToken);
        emit FeesCollected(address(this), fee, fromToken);
    }

    function setFeeRate(uint256 _feeRate) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        feeRate = _feeRate;
    }

    function banUser(address user) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _revokeRole(USER_ROLE, user);
        emit UserBanned(user);
    }

    function registerUser(address user) external {
        _grantRole(USER_ROLE, user);
        emit UserRegistered(user);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve1, reserve2);
    }

    function getFeeRate() external view returns (uint256) {
        return feeRate;
    }

    function getCollectedFees(address token) external view returns (uint256) {
        return collectedFees[token];
    }

    

    function _updateConstantFormula() internal {
        constantK = reserve1 * reserve2;
        require(constantK > 0, "Constant formula not updated");
    }

    function estimateOutputAmount(uint256 amountIn, address fromToken) public view returns (uint256 expectedAmount) {
        require(amountIn>0, "Amount In need to be greater than 0");
        require((fromToken == token1) || (fromToken == token2), "From token is not token of the pool");

        uint256 fee = (amountIn * feeRate) / 10000;
        uint256 amountInAfterFee = amountIn - fee;

        if(fromToken == token1){
            expectedAmount = reserve2 - (constantK / (reserve1 + amountInAfterFee));
        }else{
            expectedAmount = reserve1 - (constantK / (reserve2 + amountInAfterFee));
        }
    }

    function collectFees(address token, uint256 amount) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(amount > 0, "Fee amount must be greater than 0");
        collectedFees[token] += amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer of fee failed");
        emit FeesCollected(msg.sender, amount, token);
    }

    // 990909090909090909091 token2 balance
    // 989000000000000000000 token1 balance

    // 994285714285714285714
    // 994285714285714285714

    // 993000000000000000000 token1 balance
    // 993000000000000000000 token1 balance

    // 996000000000000000000

}