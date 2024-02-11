// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPool {

    function stakeTokens(bytes32 vaultId, address onBehalfOf, uint256 amount) external;
    function stakeNfts(bytes32 vaultId, address onBehalfOf, uint256 amount) external;
    
}