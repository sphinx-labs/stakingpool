// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Calnix
 * @notice Defines the error messages emitted by the different contracts of the Moca protocol
 */

library Errors {

    error InsufficientTimeLeft();
    error NonExistentVault(bytes32 vaultId);
    error VaultNotMatured(bytes32 vaultId);

    error VaultMatured(bytes32 vaultId);

}