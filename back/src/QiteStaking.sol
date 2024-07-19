// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract QiteStaking is Ownable, AccessControl {
    IERC20 public stakingToken;
    uint256 public rewardRate; // Reward rate per second
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewardBalance;
    mapping(address => uint256) public lastUpdate;

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken, uint256 _rewardRate, address initialOwner) Ownable(initialOwner) {
        stakingToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            rewardBalance[account] += earned(account);
            lastUpdate[account] = block.timestamp;
        }
        _;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        require(amount > 0, "Cannot stake 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external updateReward(msg.sender) {
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        require(amount > 0, "Cannot unstake 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        stakingToken.transfer(msg.sender, amount);
        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        emit Unstaked(msg.sender, amount);
    }

    function earned(address account) public view returns (uint256) {
        return stakedBalance[account] * rewardRate * (block.timestamp - lastUpdate[account]);
    }

    function getReward() external updateReward(msg.sender) returns (uint256){
        require(hasRole(USER_ROLE, msg.sender), "Caller is not a registered user");
        uint256 reward = rewardBalance[msg.sender];
        require(reward > 0, "No reward available");
        rewardBalance[msg.sender] = 0;
        stakingToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
        return reward;
    }

    function updateRewardRate(uint256 newRewardRate) external onlyOwner {
        rewardRate = newRewardRate;
    }
}
