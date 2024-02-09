// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

//accesscontrol

//Note: inherit ERC20 to issue stkMOCA
contract Pool is ERC20 { 
    using SafeERC20 for IERC20;

    // rp contract interface, token interface, NFT interface,
    IERC20 public MOCA_TOKEN;  
    IERC20 public LOCKED_NFT_TOKEN;  

    IERC20 public REWARD_TOKEN;
    // IERC777 - NFT
    address public REALM_POINTS;
    address public REWARDS_VAULT;
    
    uint256 public constant PRECISION = 18;    //token dp

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

    event StakedMoca(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);
    event StakedMocaNft(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);

    event RewardsAccrued(address indexed user, uint256 amount);
    event NftFeesAccrued(address indexed user, uint256 amount);

    event RewardsClaimed(bytes32 indexed vaultId, address indexed user, uint256 amount);
    event CreatorRewardsClaimed(bytes32 indexed vaultId, address indexed creator, uint256 amount);
    event NftRewardsClaimed(bytes32 indexed vaultId, address indexed creator, uint256 amount);


//------------------------------------------------------------------------------

    // user can own one or more Vaults, each one with a bytes32 identifier
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;              
                   
    // Tracks unclaimed rewards accrued for each user: user -> vaultId -> userInfo
    mapping(address user => mapping (bytes32 vaultId => DataTypes.UserInfo userInfo)) public users;

//------------------------------------------------------------------------------


    constructor(IERC20 stakedToken, IERC20 rewardToken, address realmPoints, address rewardsVault, uint128 startTime_, uint128 duration, uint128 amount, 
        string memory name, string memory symbol) ERC20(name, symbol) payable {
    
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
            // fees: note: precision check
            vault.accounting.totalFees = nftFee + creatorFee;
            vault.accounting.totalNftFee = nftFee;
            vault.accounting.creatorFee = creatorFee;
            // index
            vault.accounting.vaultIndex = uint128(newPoolIndex);
            vault.accounting.vaultLastUpdateTimestamp = uint128(currentTimestamp);

        vaults[vaultId] = vault;

        //build userInfo
        //DataTypes.UserInfo memory userInfo; 

        emit VaultCreated(msg.sender, vaultId, vaultEndTime, duration); //emit totaLAllocPpoints updated?
    }  

    function stakeTokens(bytes32 vaultId, address onBehalfOf, uint256 amount) external {
        // usual blah blah checks
        require(block.timestamp >= startTime, "Not started");       //note: do we want?
        require(amount > 0, "Invalid amount");
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
        DataTypes.Vault memory vault = vaults[vaultId];
        if (vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);
        
        // get userInfo for said vault
        DataTypes.UserInfo memory userInfo = users[onBehalfOf][vaultId];
       
        // update indexes and book all prior rewards
        _updateUserIndex(onBehalfOf, vaultId);

        // update user's stakedTokens
        userInfo.stakedTokens += uint128(amount);

        // calc. incoming allocPoints
        uint128 incomingAllocPoints = uint128(amount * vault.multiplier);
        // update allocPoints: user, vault, pool
        userInfo.allocPoints += incomingAllocPoints;
        vault.allocPoints += incomingAllocPoints;
        totalAllocPoints += incomingAllocPoints;

        // check if first stake: eligible for bonusBall
        if (vault.stakedTokens == 0){
            userInfo.accRewards = vault.accounting.bonusBall;
        }

        // mint stkMOCA
        _mint(onBehalfOf, amount);

        // grab MOCA
        MOCA_TOKEN.safeTransferFrom(onBehalfOf, address(this), amount);

        emit StakedMoca(onBehalfOf, vaultId, amount);
    }

    function stakeNfts(bytes32 vaultId, uint256 amount) external {
        // usual blah blah checks
        require(block.timestamp >= startTime, "Not started");       //note: do we want?
        require(amount > 0, "Invalid amount");
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
        DataTypes.Vault memory vault = vaults[vaultId];
        if (vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);
        
        // get userInfo for said vault
        DataTypes.UserInfo memory userInfo = users[onBehalfOf][vaultId];
       
        // update indexes and book all prior rewards
        _updateUserIndex(onBehalfOf, vaultId);

        vault.stakedNfts += amount;
        
        //note: mint stkMocaNft?
        
        // grab MOCA
        LOCKED_NFT_TOKEN.safeTransferFrom(onBehalfOf, address(this), amount);

        emit StakedMocaNft(onBehalfOf, vaultId, amount);

    }

    function claimRewards(bytes32 vaultId, address onBehalfOf) external {
        // usual blah blah checks
        require(block.timestamp >= startTime, "Not started");       //note: do we want?
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
        DataTypes.Vault memory vault = vaults[vaultId];         //storage point then cache?
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);
        
        // get userInfo for said vault
        DataTypes.UserInfo memory userInfo = users[onBehalfOf][vaultId];

        // update indexes and book all prior rewards
        _updateUserIndex(onBehalfOf, vaultId);

        uint256 totalUnclaimedRewards = userInfo.accRewards - userInfo.claimedRewards;
        userInfo.claimedRewards += totalUnclaimedRewards;
        
        //update storage
        users[user][vaultId] = userInfo;

        emit RewardsClaimed(vaultId, onBehalfOf, totalUnclaimedRewards);

        // transfer rewards to user, from rewardsVault
        MOCA_TOKEN.safeTransferFrom(REWARDS_VAULT, onBehalfOf, totalUnclaimedRewards);
    }

    function claimFees(bytes32 vaultId, address onBehalfOf) external {
        // usual blah blah checks
        require(block.timestamp >= startTime, "Not started");       //note: do we want?
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
        DataTypes.Vault memory vault = vaults[vaultId];         //storage point then cache?
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);
        
        // get userInfo for said vault
        DataTypes.UserInfo memory userInfo = users[onBehalfOf][vaultId];

        // update indexes and book all prior rewards
        _updateUserIndex(onBehalfOf, vaultId);

        uint256 totalUnclaimedRewards;
        // collect creator fees
        if(vault.creator == onBehalfOf) {
            uint256 unclaimedCreatorRewards = (vault.accounting.accCreatorRewards - userInfo.claimedCreatorRewards);
            totalUnclaimedRewards += unclaimedCreatorRewards;

            userInfo.claimedCreatorRewards += unclaimedCreatorRewards;          

            emit CreatorRewardsClaimed(vaultId, onBehalfOf, unclaimedCreatorRewards);
        }
        
        // collect NFT fees
        if(userInfo.stakedNfts > 0){
            uint256 unclaimedNftRewards = (userInfo.accNftBoostRewards - userInfo.claimedNftRewards);
            totalUnclaimedRewards += unclaimedNftRewards;

            userInfo.claimedNftRewards += unclaimedNftRewards;
         
            emit NftRewardsClaimed(vaultId, onBehalfOf, unclaimedNftRewards);
        }

        //update storage
        users[user][vaultId] = userInfo;

        // transfer rewards to user, from rewardsVault
        MOCA_TOKEN.safeTransferFrom(REWARDS_VAULT, onBehalfOf, totalUnclaimedRewards);
    } 

    function unstake(bytes32 vaultId) external {
        // usual blah blah checks
        require(block.timestamp >= startTime, "Not started");       //note: do we want?
        require(vaultId > 0, "Invalid vaultId");

        // get vault + check if has been created
        DataTypes.Vault memory vault = vaults[vaultId];         //storage point then cache?
        if(vault.creator == address(0)) revert Errors.NonExistentVault(vaultId);
        
        // check maturity
        if(vault.endTime > block.timestamp) revert Errors.VaultNotMatured(vaultId);


    }
    
    ///@dev to prevent index drift
    function updateVault(bytes32 vaultId) external {}

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
    function _calculateRewards(uint256 allocPoints, uint256 currentIndex, uint256 priorIndex) internal view returns (uint256) {
        return (allocPoints * (currentIndex - priorIndex)) / 10 ** PRECISION;
    }

    ///@dev called prior to affecting any state change to a vault
    ///@dev book prior rewards, update vaultIndex, totalAccRewards
    function _updateVaultIndex(bytes32 vaultId) internal returns(uint256, uint256) {
        //1. called on vault state-change: stake, claimRewards
        //2. book prior rewards, before affecting statechange
        //3. vaulIndex = newPoolIndex

        // cache: get vault
        DataTypes.Vault memory vault = vaults[vaultId];

        // note: is vault mature? not mature dont update userIndex

        // get latest poolIndex
        (uint256 newPoolIndex, uint256 currentTimestamp) = _updatePoolIndex();
        
        uint256 accruedRewards;
        if (vault.accounting.vaultIndex != newPoolIndex) {
            if (vault.stakedTokens > 0) {

                // calc. prior unbooked rewards 
                accruedRewards = _calculateRewards(vault.allocPoints, newPoolIndex, vault.accounting.vaultIndex);

                // calc. fees
                uint256 accCreatorFee = (accruedRewards * vault.accounting.creatorFee) / 10 ** PRECISION;
                uint256 accTotalNFTFee = (accruedRewards * vault.accounting.totalNftFee) / 10 ** PRECISION;  

                // book rewards: total, creator, NFT
                vault.accounting.totalAccRewards += accruedRewards;
                vault.accounting.accCreatorRewards += accCreatorFee;
                vault.accounting.accNftBoostRewards += accTotalNFTFee;
                // rewardsAccPerNFT
                vault.accounting.vaultNftIndex += (accTotalNFTFee / vault.stakedNfts);

            } else { // no tokens staked: no fees. only bonusBall
                
                // calc. prior unbooked rewards 
                accruedRewards = _calculateRewards(vault.allocPoints, newPoolIndex, vault.accounting.vaultIndex);

                // rewards booked to bonusBall: incentive for 1st staker
                vault.accounting.bonusBall += accruedRewards;
                vault.accounting.totalAccRewards += accruedRewards;
            }

            //update vaultIndex + vault timestamp
            vault.accounting.vaultIndex = newPoolIndex;
            vault.accounting.vaultLastUpdateTimestamp = currentTimestamp;

            //update storage
            vaults[vaultId] = vault;
            
            emit VaultIndexUpdated(vaultId, newPoolIndex, vault.accounting.totalAccRewards);

            return (newPoolIndex, vault.accounting.vaultNftIndex);
        }
    }

    ///@dev called prior to affecting any state change to a user
    ///@dev applies fees onto the vaulIndex to return the userIndex
    function _updateUserIndex(address user, bytes32 vaultId) internal returns (uint256) {

        // cache: get userInfo + vault
        DataTypes.Vault storage vault = vaults[vaultId];
        DataTypes.UserInfo memory userInfo = users[user][vaultId];
        
        // get lestest vaultIndex + vaultNftIndex
        (uint256 newVaultIndex, uint256 newUserNftIndex) = _updateVaultIndex(vaultId);

        // apply fees 
        uint256 newUserIndex = (newVaultIndex * vault.accounting.totalFees) / 10 ** PRECISION;

        //calc. user's allocPoints
        uint256 userAllocPoints = userInfo.stakedTokens * vault.multiplier;

        uint256 accruedRewards;
        if(userInfo.userIndex != newUserIndex) {
            if(userInfo.stakedTokens > 0) {
                // rewards from staking MOCA
                accruedRewards = _calculateRewards(userAllocPoints, newUserIndex, userInfo.userIndex);
                userInfo.accRewards += accruedRewards;
                emit RewardsAccrued(user, accruedRewards);
            }
        }

        if(userInfo.stakedNfts > 0) {
            if(userInfo.userNftIndex != newUserNftIndex){
                // total accrued rewards from staking NFTs
                uint256 accNftBoostRewards = (newUserNftIndex - userInfo.userNftIndex) * userInfo.stakedNfts;
                userInfo.accNftBoostRewards += accNftBoostRewards;
                emit NftFeesAccrued(user, accNftBoostRewards);
            }
        }

        //update userIndex
        userInfo.userIndex = newUserIndex;
        userInfo.userNftIndex = newUserNftIndex;

        //update storage
        users[user][vaultId] = userInfo;

        emit UserIndexUpdated(user, vaultId, newUserIndex, userInfo.accRewards);
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
            nextVaultIndex = ((emissisonPerSecond * timeDelta * 10 ** MOCA_PRECISION) / totalBalance) + currentVaultIndex;
        
            return nextVaultIndex;
        }
    }
 
  */ 