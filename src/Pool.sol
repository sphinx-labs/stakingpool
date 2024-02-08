// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
//accesscontrol

//Note: inherit ERC20 to issue stkMOCA
contract Pool { 

    // rp contract interface, token interface, NFT interface,
    IERC20 public STAKED_TOKEN;  
    IERC20 public REWARD_TOKEN;
    // IERC777 - NFT
    address public REALM_POINTS;
    address public REWARDS_VAULT;
    
    uint16 public constant PRECISION = 18;    //token dp
    uint16 public constant vaultBaseAllocPoints = 100;    
    
    uint256 public immutable startTime;           // start time
    uint256 public immutable endTime;             // 120days from start time
     
    // rewards: x
    //uint256 public totalStakedTokens;
    uint256 public totalAllocPoints;                // totalBalanceBoosted
    uint256 public poolEmissisonPerSecond;              // if top-up, can change 
    
    // rewards: y
    uint256 public poolIndex;                       // rewardsAccPerAllocPoint (to date) || rewards are booked into index
    uint256 public poolLastUpdateTimeStamp;

    // EVENTS
    event VaultCreated(address indexed creator, bytes32 indexed vaultId, uint40 indexed endTime, DataTypes.VaultDuration duration);
    event PoolIndexUpdated(address indexed asset, uint256 indexed oldIndex, uint256 indexed newIndex);
    event VaultIndexUpdated(bytes32 indexed vaultId, uint256 vaultIndex, uint256 vaultAccruedRewards);
    event UserIndexUpdated(address indexed user, bytes32 indexed vaultId, uint256 userIndex, uint256 userAccruedRewards);

//------------------------------------------------------------------------------

    // user can own one or more Vaults, each one with a bytes32 identifier
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;              
                   
    // Tracks unclaimed rewards accrued for each user: user -> vaultId -> userInfo
    mapping(address user => mapping (bytes32 vaultId => DataTypes.UserInfo userInfo)) public users;

//------------------------------------------------------------------------------


    constructor(IERC20 stakedToken, IERC20 rewardToken, address realmPoints, address rewardsVault, uint128 startTime_, uint128 duration, uint128 amount) payable {
    
        STAKED_TOKEN = stakedToken;
        REWARD_TOKEN = rewardToken;
        // NFT
        REALM_POINTS = realmPoints;
        REWARDS_VAULT = rewardsVault;

        // duration
        require(startTime_ > block.timestamp && duration > 0, "Invalid duration");
        startTime = startTime_;
        endTime = startTime_ + duration;   
        
        // eps 
        poolEmissisonPerSecond = amount / duration;

        // sanity checks
        require(poolEmissisonPerSecond > 0, "reward rate = 0");
        require(poolEmissisonPerSecond * duration <= REWARD_TOKEN.balanceOf(REWARDS_VAULT), "reward amount > balance");
    }


    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    ///@dev creates empty vault
    function createVault(uint8 salt, DataTypes.VaultDuration duration, uint8 creatorFee, uint8 nftFee) external {
        //rp check

        // period check 
        // Note:given that we maximally 120 days to now, should not overflow uint40
        uint40 vaultEndTime = uint40(block.timestamp + (30 days * uint8(duration))); 
        if (endTime <= vaultEndTime) {
            revert Errors.InsufficientTimeLeft();
        }

        // vaultId generation
        bytes32 vaultId = _generateVaultId(salt);
        while (vaults[vaultId].vaultId != bytes32(0)) {         //If vaultId exists, generate new random Id
            _generateVaultId(++salt);
        }

        // update poolIndex: allocPoints changed. book prior rewards, based on prior alloc points.
        // updates index + timestamp 
        (uint256 newPoolIndex, uint256 currentTimestamp) = _updatePoolIndex();

        // update poolAllocPoints
        uint16 vaultAllocPoints = vaultBaseAllocPoints * uint16(duration);        //duration multiplier: 30:1, 60:2, 90:3
        totalAllocPoints += vaultAllocPoints;
        
        // build vault
        DataTypes.Vault memory vault; 
            vault.vaultId = vaultId;
            vault.creator = msg.sender;
            vault.duration = duration;
            vault.endTime = vaultEndTime; 

            vault.allocPoints = vaultAllocPoints;        // vaultAllocPoints: 30:1, 60:2, 90:3
            // fees
            vault.accounting.nftFee = nftFee;
            vault.accounting.creatorFee = creatorFee;
            // index
            vault.accounting.vaultIndex = uint128(newPoolIndex);
            vault.accounting.vaultLastUpdateTimestamp = uint128(currentTimestamp);

        vaults[vaultId] = vault;

        //build userInfo
        //DataTypes.UserInfo memory userInfo; 

        emit VaultCreated(msg.sender, vaultId, vaultEndTime, duration); //emit totaLAllocPpoints updated?
    }  

    function stakeTokens(uint256 amount, bytes32 vaultId) external {
        // usual blah blah checks

        // is first stkera? bonusBalls?

        // get vault
        DataTypes.Vault memory vault = vaults[vault];
        
        // calc. incoming allocPoints
        uint256 multiplier = vault.stakedNFTs + vault.duration; //@note: anyhow
        vault.allocPoints += amount * multiplier;

        //updateState();
        uint256 unbookedRewards = _updateState(msg.sender, );

        // update pool 
        (uint256 newPoolIndex, uint256 currentTimestamp) = _updatePoolIndex();
        //update totalAllocPoints 
        //totalAllocPoints += vaultAllocPoints;

        //update vault
        _updateVault(vaultId);
    }
    
    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    
    // updates poolIndex + poolLastUpdateTimestamp
    function _updatePoolIndex() internal returns (uint256, uint256) {
        uint256 oldPoolIndex = poolIndex;
        uint256 oldPoolLastUpdateTimestamp = poolLastUpdateTimeStamp;

        if(block.timestamp == oldPoolLastUpdateTimestamp) {
            return (oldPoolIndex, oldPoolLastUpdateTimestamp);
        }
        
        // totalBalance = totalAllocPoints (boosted balance)
        (uint256 nextPoolIndex, uint256 currentTimestamp) = _calculatePoolIndex(oldPoolIndex, poolEmissisonPerSecond, poolLastUpdateTimeStamp, totalAllocPoints);

        if(nextPoolIndex != oldPoolIndex) {
            poolIndex = nextPoolIndex;

            emit PoolIndexUpdated(address(REWARD_TOKEN), oldPoolIndex, nextPoolIndex);
        }

        poolLastUpdateTimeStamp = block.timestamp;

        return (nextPoolIndex, currentTimestamp);
    }

    function _calculatePoolIndex(uint256 currentPoolIndex, uint256 emissisonPerSecond, uint256 lastUpdateTimestamp, uint256 totalBalance) internal view returns (uint256, uint256) {
        if (
            emissisonPerSecond == 0                          // 0 emissions. no rewards setup.
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // assetIndex already updated
            || lastUpdateTimestamp >= endTime                // distribution has ended
        ) {

            return (currentPoolIndex, lastUpdateTimestamp);                       
        }

        uint256 currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;

        uint256 nextPoolIndex = ((emissisonPerSecond * timeDelta * 10 ** PRECISION) / totalBalance) + currentPoolIndex;
    
        return (nextPoolIndex, currentTimestamp);
    }

    ///@dev balance == allocPoints
    ///@dev vaultIndex/userIndex == userIndex
    function _calculateRewards(uint256 allocPoints, uint256 poolIndex, uint256 userIndex) internal view returns (uint256) {
        return (allocPoints * (poolIndex - userIndex)) / 10 ** PRECISION;
    }

    ///@dev called prior to affecting any state change to a vault
    ///@dev book prior rewards, update vaultIndex, totalAccRewards
    function _updateVaultIndex(bytes32 vaultId) internal returns(uint256) {
        //1. called on vault state-change: stake, claimRewards
        //2. book prior rewards, before affecting statechange
        //3. vaulIndex = newPoolIndex

        // cache: get vault
        DataTypes.Vault memory vault = vaults[vaultId];

        // is vault mature? not mature dont update userIndex

        // get latest poolIndex
        (uint256 newPoolIndex, uint256 currentTimestamp) = _updatePoolIndex();
        
        uint256 accruedRewards;
        if (vault.accounting.vaultIndex != newPoolIndex) {
            if (vault.stakedTokens > 0) {
                // calc. prior unbooked rewards 
                accruedRewards = _calculateRewards(vault.allocPoints, newPoolIndex, vault.accounting.vaultIndex);
                
                // book rewards
                vault.accounting.totalAccRewards += accruedRewards;
                
            } else { // no tokens staked

                // calc. prior unbooked rewards 
                accruedRewards = _calculateRewards(vault.allocPoints, newPoolIndex, vault.accounting.vaultIndex);
                
                // rewards booked to bonusBall: incentive for 1st staker
                vault.accounting.bonusBall += accruedRewards;
                vault.accounting.totalAccRewards += accruedRewards;
            }

            //note: what about fees-rewards?

            //update vaultIndex + vault timestamp
            vault.accounting.vaultIndex = newPoolIndex;
            vault.accounting.vaultLastUpdateTimestamp = currentTimestamp;

            //update storage
            vaults[vaultId] = vault;
            
            emit VaultIndexUpdated(vaultId, newPoolIndex, vault.accounting.totalAccRewards);

            return newPoolIndex;
        }
    }

    ///@dev called prior to affecting any state change to a user
    function _updateUserIndex(address user, bytes32 vaultId) internal returns (uint256) {

        // cache: get userInfo + vault
        DataTypes.Vault storage vault = vaults[vaultId];
        DataTypes.UserInfo memory userInfo = users[user][vaultId];
        
        // get lestest vaultIndex
        uint256 newVaultIndex = _updateVaultIndex(vaultId);

        //calc. user's allocPoints
        uint256 userAllocPoints = userInfo.stakedTokens * vault.multiplier;


        uint256 accruedRewards;
        if(userInfo.userIndex != newVaultIndex) {
            if(userInfo.stakedTokens > 0) {
                accruedRewards = _calculateRewards(userAllocPoints, newVaultIndex, userInfo.userIndex);

                userInfo.accRewards += accRewards;
            }

            userInfo.userIndex = newVaultIndex;

            //update storage
            users[user][vaultId] = userInfo;

            emit UserIndexUpdated(user, vaultId, newVaultIndex, userInfo.accRewards);;
        }
        


    }


    ///@dev Generate a vaultId. keccak256 is cheaper than using a counter with a SSTORE, even accounting for eventual collision retries.
    function _generateVaultId(uint8 salt) internal view returns (bytes32) {
        return bytes32(keccak256(abi.encode(msg.sender, block.timestamp, salt)));
    }


}




/**
Issue with mapping addr to dynamic array

- No check for duplicates / No assurance of uniqueness
    on restaking to the same vault, must loop through all the structs

    mapping(address user => []vaultIds)                 // ? may not be needed
    mapping(bytes32 hash(addr,vaultId) => SubscriptionInfo) // if user did not sub vault, default struct value?

 */


 /**
 
     function _calculatePoolIndex(uint256 currentPoolIndex, uint256 emissisonPerSecond, uint128 lastUpdateTimestamp, uint256 totalBalance) internal view returns (uint256) {
        if (
            emissisonPerSecond == 0                           // 0 emissions. no rewards setup.
            || totalBalance == 0                             // nothing has been staked
            || lastUpdateTimestamp == block.timestamp        // assetIndex already updated
            || lastUpdateTimestamp >= endTime                // distribution has ended
        ) {

            return currentPoolIndex;                       
        }

        uint256 currentTimestamp = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;

        if(totalBalance == 0) {
            uint256 bonusBall = emissisonPerSecond * timeDelta;
            return currentVaultIndex;   // returns 0 
        
        } else {

            uint256 nextVaultIndex; 
            nextVaultIndex = ((emissisonPerSecond * timeDelta * 10 ** PRECISION) / totalBalance) + currentVaultIndex;
        
            return nextVaultIndex;
        }
    }
 
  */ 