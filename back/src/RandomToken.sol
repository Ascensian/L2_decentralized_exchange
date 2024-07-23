// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract RandomToken is ERC20 {

    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol) {
        _mint(msg.sender, 1000*10**decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}