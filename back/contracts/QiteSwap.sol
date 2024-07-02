// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./QitePool.sol";
import "./QiteStaking.sol";

contract QiteSwap {
    mapping(address => mapping(address => QitePool)) public getPair;
    address[] public allPairs;
    QiteStaking public stakingContract;
    event PairCreated(address indexed token1, address indexed token2, address pair);

    constructor(address _stakingContract) {
        stakingContract = QiteStaking(_stakingContract);
    }


    function createPairs(address token1, address token2, string calldata token1Name, string calldata token2Name) external returns(address) {
        // Require some checks 
        require(token1 != token2, "Identical address is not allowed");
        require(address(getPair[token1][token2]) == address(0), "Pair already created");
        // Create liquidity pool
        string memory liquidityTokenName = string(abi.encodePacked("Liquidity-",token1Name,"-",token2Name));
        string memory liquiditySymbol = string(abi.encodePacked("LP-",token1Name,"-",token2Name));
        QitePool qitePool = new QitePool(token1, token2, liquidityTokenName,liquiditySymbol);
        // Update state variable
        allPairs.push(address(qitePool));
        getPair[token1][token2] = qitePool;
        getPair[token2][token1] = qitePool;
        // emit event 
        emit PairCreated(token1, token2, address(qitePool));
        // return Qite Pool address
        return address(qitePool);
    }

    function allPairsLength() external view returns(uint256) {
        return allPairs.length;
    }

    function getPairs() external view returns(address[] memory) {
        return allPairs;
    }

    function stakeLiquidityTokens(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        QitePool pool = QitePool(msg.sender);
        pool.liquidityToken().transferFrom(msg.sender, address(this), amount);
        pool.liquidityToken().approve(address(stakingContract), amount);
        stakingContract.stake(amount);
    }

    function unstakeLiquidityTokens(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");
        stakingContract.unstake(amount);
        QitePool pool = QitePool(msg.sender);
        pool.liquidityToken().transfer(msg.sender, amount);
    }

}