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
        uint128 allocPoints; 

        // staked assets
        uint8 stakedNfts;            //2^8 -1 NFTs
        uint128 stakedTokens;

        VaultAccounting accounting;
    }

    struct VaultAccounting{
        // index
        uint256 vaultIndex;    
        uint256 vaultLastUpdateTimestamp;
        uint256 vaultNftIndex;    //rewardsAccPerNFT
        
        // fees: pct values, with 18dp precision
        uint256 totalFees;   
        uint256 creatorFee;   
        uint256 totalNftFee;       
            
        // rewards
        uint256 totalAccRewards;
        uint256 accNftBoostRewards;
        uint256 accCreatorRewards;    
        uint256 bonusBall;
    }


    /*//////////////////////////////////////////////////////////////
                                  USER
    //////////////////////////////////////////////////////////////*/

    struct UserInfo {
        bytes32 vaultId;    

        // staked assets
        uint8 stakedNfts;            //2^8 -1 NFTs
        uint128 stakedTokens;
        uint128 allocPoints; 

        // indexes
        uint256 userIndex; 
        uint256 userNftIndex;

        //rewards: tokens
        uint256 accRewards;
        uint256 claimedRewards;

        //rewards: NFTs
        uint256 accNftBoostRewards; 
        uint256 claimedNftRewards;

        //rewards: creatorFees
        uint256 claimedCreatorRewards;
    }
}