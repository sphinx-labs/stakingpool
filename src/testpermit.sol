// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "./../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";


contract MocaToken is ERC20, ERC20Permit {

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name){}

    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        _burn(user, amount);
    }
}