// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract LiquidityToken is ERC20, AccessControl {

    constructor(string memory _tokenName,string memory _tokenSymbol) ERC20(_tokenName, _tokenSymbol){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    function burn(address to , uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(to, amount);
    }

}