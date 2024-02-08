// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract DataTypes {

    enum VaultDuration{
        NONE,       //0
        THIRTY,     //1
        SIXTY,      //2 
        NINETY      //3
    }

    struct Vault {
        bytes32 vaultId;   
        address creator;

        VaultDuration duration;     //uint8
        //uint40 startTime;
        uint40 endTime;             //uint40
        
        uint128 multiplier;
        uint16 allocPoints; 

        // staked assets
        uint8 stakedNFTs;            //2^8 -1 NFTs
        uint128 stakedTokens;

        VaultAccounting accounting;
    }

    struct VaultAccounting{
        // fees
        uint8 nftFee;
        uint8 creatorFee;

        // index
        uint128 vaultIndex;    
        uint128 vaultLastUpdateTimestamp;
      
        // rewards
        uint128 totalAccRewards;
        uint128 accNftBoostRewards;
        uint128 accCreatorRewards;      // accUserRewards?
        uint128 bonusBall;
    }


    /*//////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct UserInfo {
        bytes32 vaultId;   
        bool isCreator;

        // staked assets
        uint8 stakedNFTs;            //2^8 -1 NFTs
        uint128 stakedTokens;
        uint16 allocPoints; 

        // rewards
        uint128 userIndex; 
        uint256 accRewards;
        uint256 claimedRewards;
    }
}