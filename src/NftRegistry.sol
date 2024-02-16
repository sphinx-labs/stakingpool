// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// issues
contract NftRegistry is ERC20 {

    constructor() ERC20("bridgedNftToken", "BNT"){}

    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        _burn(user, amount);
    }

    function register() public {}

    function deregister() public {}
}