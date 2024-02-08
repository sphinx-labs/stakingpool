// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {DataTypes} from './DataTypes.sol';

contract Counter {
    uint256 public number;
    
    DataTypes.Vault public vault;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
