// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Errors} from './Errors.sol';
import {DataTypes} from './DataTypes.sol';

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
//accesscontrol

contract Pool { 

    // rp contract interface, token interface, NFT interface,
    IERC20 public STAKED_TOKEN;  
    IERC20 public REWARD_TOKEN;
    // IERC777 - NFT
    address public REALM_POINTS;
    address public REWARDS_VAULT;
    
    uint16 public constant vaultBaseAllocPoints = 100;    
    
    uint8 public constant PRECISION = 18;    

    uint128 public immutable startTime;           // start time
    uint128 public immutable endTime;             // 120days from start time
    
    // fixed unless rewards are topped up
    uint256 public poolEmissisonPerSecond;
    
    // alloc
    uint128 public totalAllocPoints;
    uint128 public allocPointsLastUpdateTimestamp;
    

    // EVENTS
    event VaultCreated(address indexed creator, bytes32 indexed vaultId, DataTypes.VaultDuration indexed duration);

//------------------------------------------------------------------------------

    // user can own one or more Vaults, each one with a bytes32 identifier
    mapping(bytes32 vaultId => DataTypes.Vault vault) public vaults;              
    
    // userHash = hash(addr, vaultId) | hash collision after 
    mapping(bytes32 userhash => DataTypes.SubscriptionInfo) public subscriptions;                           

    // track vaults assoc w/ user. may not be needed
    mapping(address user => uint256[] vaultIds) public userVaults;             

//------------------------------------------------------------------------------
    // _assetIndex
    mapping (bytes32 vaultId => uint256 vaultIndex) internal _vaultIndexes;

    // Tracks unclaimed rewards accrued for each user: user -> vaultId -> userindex
    mapping(address user => mapping (bytes32 vaultId => uint256 userindex)) internal _userIndexes;

    // Tracks unclaimed rewards accrued for each user: user -> vaultId -> unclaimedRewards
    mapping(address user => mapping (bytes32 vaultId => uint256 accruedRewards)) internal _accruedRewards;
    
    // Tracks claimed rewards: user -> vaultId -> claimedRewards
    mapping(address user => mapping (bytes32 vaultId => uint256 accruedRewards)) internal _claimedRewards;

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

        // calc. vault eps
        vaultAllocPoints = vaultBaseAllocPoints * uint16(duration);        //duration multiplier: 30:1, 60:2, 90:3
        uint128 currentTotalAllocPoints = totalAllocPoints += vaultAllocPoints;
        vaultEps = vaultAllocPoints / currentTotalAllocPoints;

        // build vault
        DataTypes.Vault memory vault; 
            vault.vaultId = vaultId;
            vault.creator = msg.sender;
            vault.duration = duration;
            vault.endTime = vaultEndTime; 
            vault.allocPoints = uint16(duration);        //vaultAllocPoints: 30:1, 60:2, 90:3
            vault.accounting.eps = vaultEps;
            vault.accounting.nftFee = nftFee;
            vault.accounting.creatorFee = creatorFee;

        vaults[vaultId] = vault;

        emit VaultCreated(msg.sender, vaultId, duration); //emit totaLAllocPpoints updated?
    }  

    function stakeTokens(uint256 amount) external {
        // usual blah blah

        //update vault
        updateVault();
    }
    
    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    ///@dev Generate a vaultId. keccak256 is cheaper than using a counter with a SSTORE, even accounting for eventual collision retries.
    function _generateVaultId(uint8 salt) internal view returns (bytes32) {
        return bytes32(keccak256(abi.encode(msg.sender, block.timestamp, salt)));
    }








    //---------------- VAULT INDEX --------------------------

    function _calculateVaultIndex(uint256 currentVaultIndex, uint256 emissisonPerSecond, uint128 lastUpdateTimestamp, uint256 totalBalance) internal view returns (uint256) {
        if (
            emissisonPerSecond == 0                         // 0 emissions. setup() not executed.
            //|| totalBalance == 0                            // nothing has been staked
            || lastUpdateTimestamp == block.timestamp       // assetIndex already updated
            || lastUpdateTimestamp >= endTime               // distribution has ended
        ) {

            return currentVaultIndex;   // returns 0, since vaultIndex has not been assign.
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











}




/**
Issue with mapping addr to dynamic array

- No check for duplicates / No assurance of uniqueness
    on restaking to the same vault, must loop through all the structs

    mapping(address user => []vaultIds)                 // ? may not be needed
    mapping(bytes32 hash(addr,vaultId) => SubscriptionInfo) // if user did not sub vault, default struct value?

 */