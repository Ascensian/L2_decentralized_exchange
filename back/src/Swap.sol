// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Pool.sol";
import "./Staking.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Swap is AccessControl {
    mapping(address => mapping(address => Pool)) public getPair;
    address[] public allPairs;
    Staking public stakingContract;
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    event PairCreated(address indexed token1, address indexed token2, address pair);

    constructor() {
       _grantRole(ADMIN_ROLE, msg.sender);
    }


    function createPairs(address token1, address token2, string calldata token1Name, string calldata token2Name, address priceFeed1, address priceFeed2) external returns(address) {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        // Require some checks 
        require(token1 != token2, "Identical address is not allowed");
        require(address(getPair[token1][token2]) == address(0), "Pair already created");
        // Create liquidity pool
        string memory liquidityTokenName = string(abi.encodePacked("Liquidity-",token1Name,"-",token2Name));
        string memory liquiditySymbol = string(abi.encodePacked("LP-",token1Name,"-",token2Name));

        Pool pool = new Pool(token1, token2, liquidityTokenName, liquiditySymbol, priceFeed1, priceFeed2);
        // Update state variable
        allPairs.push(address(pool));
        getPair[token1][token2] = pool;
        getPair[token2][token1] = pool;
        // emit event
        emit PairCreated(token1, token2, address(pool));
        // return Pool address
        return address(pool);
    }

    function allPairsLength() external view returns(uint256) {
        return allPairs.length;
    }

    function getPairs() external view returns(address[] memory) {
        return allPairs;
    }

    function setPlatformFeeRate(address token1, address token2, uint256 feeRate) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        Pool pool = getPair[token1][token2];
        require(address(pool) != address(0), "Pair does not exist");
        pool.setFeeRate(feeRate);
    }

    function banUser(address token1, address token2, address user) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        Pool pool = getPair[token1][token2];
        require(address(pool) != address(0), "Pair does not exist");
        pool.banUser(user);
    }

    function getPlatformStatistics(address token1, address token2) external view returns (uint256, uint256, uint256, uint256) {
    Pool pool = getPair[token1][token2];
    require(address(pool) != address(0), "Pair does not exist");

    uint256 reserve1;
    uint256 reserve2;
    uint256 feeRate;
    uint256 collectedFeesToken1;
    uint256 collectedFeesToken2;

    (reserve1, reserve2) = pool.getReserves();
    feeRate = pool.getFeeRate();
    collectedFeesToken1 = pool.getCollectedFees(token1);
    collectedFeesToken2 = pool.getCollectedFees(token2);

    return (reserve1, reserve2, feeRate, collectedFeesToken1 + collectedFeesToken2);
    }

}