// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IPool} from "./interfaces/IPool.sol";

contract Router {
    
    address public STAKED_TOKEN;  
    address public LOCKED_NFT_TOKEN;  

    constructor(address mocaToken, address mocaNFT){
        STAKED_TOKEN = mocaToken;
        LOCKED_NFT_TOKEN = mocaNFT;
    }


    /// @dev Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    function batch(bytes[] calldata calls) external payable returns (bytes[] memory results) {
        results = new bytes[](calls.length);

        for (uint256 i; i < calls.length; i++) {

            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) revert(_getRevertMsg(result));
            results[i] = result;
        }
    }


    /// @dev Helper function to extract a useful revert message from a failed call.
    /// If the returned data is malformed or not correctly abi encoded then this call can fail itself.
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function stake(
        bytes32 vaultId,
        address token,
        address owner,         // user
        address spender,       // router
        uint256 amount,        // amount of tokens
        uint256 deadline,      // expiry
        uint8 v, bytes32 r, bytes32 s) external {
            
        //1. permit: gain approval for stkMOCA frm user via sig
        IERC20Permit(token).permit(owner, spender, amount, deadline, v, r, s);

        //stake: router calls pool -> transferFrom 
        IPool(spender).stakeTokens(vaultId, owner, amount);

    }

}


/**
Batch teh following
1. create permit: message for user to sign - gives approval
2. batch: permit sig verification, stake
3. 
 */


 /**
 Gas-less Token Transfer - Code: https://www.youtube.com/watch?v=jYNnatXRsBs


  */