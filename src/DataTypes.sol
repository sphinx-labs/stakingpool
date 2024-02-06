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
        uint40 endTime;             //uint40
        uint16 allocPoints; 

        // staked assets
        uint8 nftStaked;            //2^8 -1 NFTs
        uint128 tokenStaked;

        VaultAccounting accounting;
    }

    struct VaultAccounting{
        // fees
        uint8 totalNftFee;
        uint8 creatorFee;

        // index
        uint128 eps;
        uint128 vaultIndex;    
        uint128 lastUpdatedTimestamp;
      
        // rewards
        uint128 totalAccRewards;
        uint128 accNftBoostRewards;
        uint128 accCreatorRewards;      // accUserRewards?
        uint128 bonusBall;
    }

    struct SubscriptionInfo {
        bytes32 vaultId;

        // staked assets
        uint8 stakedNFTs; // no. of NFTs
        uint128 stakedTokens;
        
        // rewards                
        uint256 userIndex;
        uint256 accRewards;
        uint256 claimedRewards;

        // fee
        bool isCreator;

        // misc        
        uint128 startDate;
        uint128 endDate;    //uint40
    }

    struct UserInfo {
        uint256 count;
        SubscriptionInfo[] subscriptions;
    }
}