// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

// my contracts
import {Pool} from "../src/Pool.sol";
import {RewardsVault} from "../src/RewardsVault.sol";

import {MocaToken, ERC20} from "../src/MocaToken.sol";
import {NftRegistry} from "../src/NftRegistry.sol";

import {Errors} from "../src/Errors.sol";
import {DataTypes} from "../src/DataTypes.sol";

// interfaces
import {IPool} from "../src/interfaces/IPool.sol";
import {IRewardsVault} from "../src/interfaces/IRewardsVault.sol";

// external dep
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";


abstract contract StateZero is Test {
    using stdStorage for StdStorage;

    // contracts
    Pool public stakingPool;
    RewardsVault public rewardsVault;

    // staking assets
    MocaToken public mocaToken;  
    NftRegistry public nftRegistry;      
    
    //address public REALM_POINTS;
    
    // stakingPool constructor data
    uint256 public startTime;           
    uint256 public duration;    
    uint256 public rewards;            
    string public name; 
    string public symbol;
    address public owner;

    uint256 public constant nftMultiplier = 2;
    uint256 public constant vault60Multiplier = 2;
    uint256 public constant vault90Multiplier = 3;
    uint256 public constant vaultBaseAllocPoints = 100 ether;     // need 18 dp precision for pool index calc

    // testing data
    address public userA;
    address public userB;
    address public userC;
   
    uint256 public userAPrinciple;
    uint256 public userBPrinciple;
    uint256 public userCPrinciple;

    uint256 public constant userANfts = 1;
    uint256 public constant userBNfts = 1;
    uint256 public constant userCNfts = 2;

//-------------------------------events-------------------------------------------
    event DistributionUpdated(uint256 indexed newPoolEPS, uint256 indexed newEndTime);

    event VaultCreated(address indexed creator, bytes32 indexed vaultId, uint40 indexed endTime, DataTypes.VaultDuration duration);
    event PoolIndexUpdated(address indexed asset, uint256 indexed oldIndex, uint256 indexed newIndex);
    event VaultIndexUpdated(bytes32 indexed vaultId, uint256 vaultIndex, uint256 vaultAccruedRewards);
    event UserIndexUpdated(address indexed user, bytes32 indexed vaultId, uint256 userIndex, uint256 userAccruedRewards);

    event StakedMoca(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);
    event StakedMocaNft(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);
    event UnstakedMoca(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);
    event UnstakedMocaNft(address indexed onBehalfOf, bytes32 indexed vaultId, uint256 amount);

    event RewardsAccrued(address indexed user, uint256 amount);
    event NftFeesAccrued(address indexed user, uint256 amount);

    event RewardsClaimed(bytes32 indexed vaultId, address indexed user, uint256 amount);
    event NftRewardsClaimed(bytes32 indexed vaultId, address indexed creator, uint256 amount);
    event CreatorRewardsClaimed(bytes32 indexed vaultId, address indexed creator, uint256 amount);
//-----------------------------------------------------------------------------------

    function setUp() public virtual {
        owner = address(0xABCD);

        userA = address(0xA);
        userB = address(0xB);
        userC = address(0xC);

        userAPrinciple = 50 ether;
        userBPrinciple = 30 ether; 
        userCPrinciple = 80 ether; 

        startTime = 1;          // t = 1
        duration = 120 days;
        rewards = 120 days * 1 ether;

        vm.warp(0);
        vm.startPrank(owner);

        // deploy contracts
        mocaToken = new MocaToken("MocaToken", "MOCA");
        nftRegistry = new NftRegistry("bridgedMocaNft", "bMocaNft");

        //IERC20 rewardToken, address moneyManager, address admin
        rewardsVault = new RewardsVault(IERC20(mocaToken), owner, owner);
        // rewards for emission
        mocaToken.mint(address(rewardsVault), rewards);  

        // modify rewardsVault storage
        stdstore
            .target(address(rewardsVault))
            .sig(rewardsVault.totalVaultRewards.selector) 
            .checked_write(rewards);


        // IERC20 stakedToken, IERC20 lockedNftToken, IERC20 rewardToken, address realmPoints, address rewardsVault, uint128 startTime_, uint128 duration, uint128 rewards, 
        // string memory name, string memory symbol, address owner
        stakingPool = new Pool(IERC20(mocaToken), IERC20(nftRegistry), IERC20(mocaToken), address(0), address(rewardsVault), startTime, duration, rewards, "stkMOCA", "stkMOCA", owner);

        //mint tokens to users
        mocaToken.mint(userA, userAPrinciple);
        mocaToken.mint(userB, userBPrinciple);
        mocaToken.mint(userC, userCPrinciple);

        // mint bridged NFT tokens to users
        nftRegistry.mint(userA, userANfts);
        nftRegistry.mint(userB, userBNfts);
        nftRegistry.mint(userC, userCNfts);

        vm.stopPrank();


        // approvals for receiving Moca tokens for staking
        vm.prank(userA);
        mocaToken.approve(address(stakingPool), userAPrinciple);

        vm.prank(userB);
        mocaToken.approve(address(stakingPool), userBPrinciple);

        vm.prank(userC);
        mocaToken.approve(address(stakingPool), userCPrinciple);
        
        // approval for issuing reward tokens to stakers
        vm.prank(address(rewardsVault));
        mocaToken.approve(address(stakingPool), rewards);

        // approvals for receiving bridgedNFTOKENS for staking
        vm.prank(userA);
        nftRegistry.approve(address(stakingPool), 1);

        vm.prank(userB);
        nftRegistry.approve(address(stakingPool), 1);

        vm.prank(userC);
        nftRegistry.approve(address(stakingPool), 2);


        //check stakingPool
        assertEq(stakingPool.startTime(), 1);
        assertEq(stakingPool.endTime(), 1 + 120 days);
        
        (
        uint256 totalAllocPoints, 
        uint256 emissisonPerSecond,
        uint256 poolIndex,
        uint256 poolLastUpdateTimeStamp,
        uint256 totalPoolRewards, 
        uint256 totalPoolRewardsEmitted) = stakingPool.pool();

        assertEq(totalAllocPoints, 0);
        assertEq(emissisonPerSecond, 1 ether);
        assertEq(poolIndex, 0);
        assertEq(poolLastUpdateTimeStamp, startTime);   
        assertEq(totalPoolRewards, rewards);
        assertEq(totalPoolRewardsEmitted, 0);

        // check rewards vault
        assertEq(rewardsVault.totalVaultRewards(), rewards);

        // check time
        assertEq(block.timestamp, 0);
    }

    function getPoolStruct() public returns (DataTypes.PoolAccounting memory) {
        (
            uint256 totalAllocPoints, 
            uint256 emissisonPerSecond, 
            uint256 poolIndex, 
            uint256 poolLastUpdateTimeStamp,
            uint256 totalPoolRewards,
            uint256 totalPoolRewardsEmitted

        ) = stakingPool.pool();

        DataTypes.PoolAccounting memory pool;
        
        pool.totalAllocPoints = totalAllocPoints;
        pool.emissisonPerSecond = emissisonPerSecond;

        pool.poolIndex = poolIndex;
        pool.poolLastUpdateTimeStamp = poolLastUpdateTimeStamp;

        pool.totalPoolRewards = totalPoolRewards;
        pool.totalPoolRewardsEmitted = totalPoolRewardsEmitted;

        return pool;
    }

    function getUserInfoStruct(bytes32 vaultId, address user) public returns (DataTypes.UserInfo memory){
        (
            //bytes32 vaultId_, 
            ,uint256 stakedNfts, uint256 stakedTokens, 
            uint256 userIndex, uint256 userNftIndex,
            uint256 accRewards, uint256 claimedRewards,
            uint256 accNftStakingRewards, uint256 claimedNftRewards,
            uint256 claimedCreatorRewards

        ) = stakingPool.users(user, vaultId);

        DataTypes.UserInfo memory userInfo;

        {
            //userInfo.vaultId = vaultId_;
        
            userInfo.stakedNfts = stakedNfts;
            userInfo.stakedTokens = stakedTokens;

            userInfo.userIndex = userIndex;
            userInfo.userNftIndex = userNftIndex;

            userInfo.accRewards = accRewards;
            userInfo.claimedRewards = claimedRewards;

            userInfo.accNftStakingRewards = accNftStakingRewards;
            userInfo.claimedNftRewards = claimedNftRewards;

            userInfo.claimedCreatorRewards = claimedCreatorRewards;
        }

        return userInfo;
    }

    function getVaultStruct(bytes32 vaultId) public returns (DataTypes.Vault memory) {
        (
            bytes32 vaultId_, address creator,
            DataTypes.VaultDuration duration_, uint256 endTime_,
            
            uint256 multiplier, uint256 allocPoints,
            uint256 stakedNfts, uint256 stakedTokens,
            
            DataTypes.VaultAccounting memory accounting

        ) = stakingPool.vaults(vaultId);

        DataTypes.Vault memory vault;
        
        vault.vaultId = vaultId_;
        vault.creator = creator;

        vault.duration = duration_;
        vault.endTime = endTime_;

        vault.multiplier = multiplier;
        vault.allocPoints = allocPoints;

        vault.stakedNfts = stakedNfts;
        vault.stakedTokens = stakedTokens;

        vault.accounting = accounting;

        return vault;
    }

}

//Note:  t = 0. Pool deployed but not active yet.
contract StateZeroTest is StateZero {

    function testCannotCreateVault() public {
        vm.prank(userA);

        vm.expectRevert("Not started");
        
        uint8 salt = 1;
        uint256 creatorFee = 0.10 * 1e18;
        uint256 nftFee = 0.10 * 1e18;

        stakingPool.createVault(userA, salt, DataTypes.VaultDuration.THIRTY, creatorFee, nftFee);
    }

    function testCannotStake() public {
        vm.prank(userA);

        vm.expectRevert("Not started");
        
        bytes32 vaultId = bytes32(0);
        stakingPool.stakeTokens(vaultId, userA, userAPrinciple);
    }   

    function testEmptyVaults(bytes32 vaultId) public {
        
        DataTypes.Vault memory vault = getVaultStruct(vaultId);

        assertEq(vault.vaultId, bytes32(0));
        assertEq(vault.creator, address(0));   
    }
}



abstract contract StateT01 is StateZero {

    function setUp() public virtual override {
        super.setUp();

        vm.warp(1);
    }
}

//Note: t=01, Pool deployed and active. But no one stakes.
//      discarded reward that is emitted.
//      see testDiscardedRewards() at the end.
contract StateT01Test is StateT01 {
    // placeholder


}

//Note: t=02, VaultA created. 
//      but no staking done. 
//      vault will accrued rewards towards bonusBall
abstract contract StateT02 is StateT01 {

    bytes32 public vaultIdA;

    uint8 public saltA = 123;
    uint256 public creatorFeeA = 0.10 * 1e18;
    uint256 public nftFeeA = 0.10 * 1e18;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(2);

        vaultIdA = generateVaultId(saltA, userA);

        // create vault
        vm.prank(userA);       
        stakingPool.createVault(userA, saltA, DataTypes.VaultDuration.THIRTY, creatorFeeA, nftFeeA);
    }
    
    function generateVaultId(uint8 salt, address onBehalfOf) public view returns (bytes32) {
        return bytes32(keccak256(abi.encode(onBehalfOf, block.timestamp, salt)));
    }

}

contract StateT02Test is StateT02 {

    // cannot claim
    // cannot unstake

    function testNewVaultCreated() public {
        // check vault
        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        assertEq(vaultA.vaultId, vaultIdA);
        assertEq(userA, vaultA.creator);
        assertEq(uint8(DataTypes.VaultDuration.THIRTY), uint8(vaultA.duration));
        assertEq(block.timestamp + 30 days, vaultA.endTime);   // 2592002 [2.592e6]

        assertEq(1, vaultA.multiplier);              // 30Day multiplier
        assertEq(100 ether, vaultA.allocPoints);     // baseAllocPoints: 1e20
        assertEq(0, vaultA.stakedNfts);
        assertEq(0, vaultA.stakedTokens);

        // accounting
        assertEq(0, vaultA.accounting.vaultIndex);
        assertEq(0, vaultA.accounting.vaultNftIndex);

        assertEq(creatorFeeA + nftFeeA, vaultA.accounting.totalFeeFactor);
        assertEq(creatorFeeA, vaultA.accounting.totalNftFeeFactor);
        assertEq(nftFeeA, vaultA.accounting.totalNftFeeFactor);

        assertEq(0, vaultA.accounting.totalAccRewards);
        assertEq(0, vaultA.accounting.accNftStakingRewards);
        assertEq(0, vaultA.accounting.accCreatorRewards);
        assertEq(0, vaultA.accounting.bonusBall);

        assertEq(0, vaultA.accounting.claimedRewards);

    }

    function testCanStake() public {
        
        vm.prank(userA);
        stakingPool.stakeTokens(vaultIdA, userA, 1e18);
        // check events
        // check staking stuff
    }

    // vault created. therefore, poolIndex has been updated.
    function testPoolAccounting() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
        
        // totalAllocPoints: 100, emissisonPerSecond: [1e18], 
        // poolIndex: 0, poolLastUpdateTimeStamp: 2, 
        // totalPoolRewards: 10368000000000000000000000 [1.036e25], totalPoolRewardsEmitted: 0

        assertEq(pool.totalAllocPoints, vaultBaseAllocPoints);   // 1 new vault w/ no staking
        assertEq(pool.emissisonPerSecond, 1 ether);
        
        assertEq(pool.poolIndex, 0);
        assertEq(pool.poolLastUpdateTimeStamp, startTime + 1);   

        assertEq(pool.totalPoolRewards, rewards);
        assertEq(pool.totalPoolRewardsEmitted, 0);
    }

}

//Note: t=03,  
//      userA stakes into VaultA and receives bonusBall reward. 
//      check bonusBall accrual on first stake.
abstract contract StateT03 is StateT02 {

    function setUp() public virtual override {
        super.setUp();

        vm.warp(3);

        vm.prank(userA);
        stakingPool.stakeTokens(vaultIdA, userA, userAPrinciple);
    }

}

//Note: check that all values are updated correctly after the 1st stake has been made into vaultA.
contract StateT03Test is StateT03 {

    // check tt staking was received and recorded correctly
    // check vault and userInfo

    function testPoolT03() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
        /**
            From t=2 to t=3, Pool emits 1e18 rewards
            There is only 1 vault in existence, which receives the full 1e18 of rewards
            No user has staked at the moment, so this is booked as bonusBall
             - rewardsAccruedPerToken = 1e18 / vaultBaseAllocPoint 
                                      = 1e18 / 100e18
                                      = 1e16
             - poolIndex should therefore be updated to 1e16 (index represents rewardsPerToken since inception)

            Calculating index:
            - poolIndex = (eps * timeDelta / totalAllocPoints) + oldIndex
             - eps: 1 
             - oldIndex: 0
             - timeDelta: 1 seconds 
             - totalAllocPoints: 100e18
            
            - poolIndex = (1 * 1 / 100e18 ) + 0 = 0.01 * 1e18 = 1e16
        */

        assertEq(pool.totalAllocPoints, userAPrinciple); // poolAllocPoints reset to match user's stake. no more vaultBaseAllocPoints
        assertEq(pool.emissisonPerSecond, 1 ether);

        assertEq(pool.poolIndex, 1e16);
        assertEq(pool.poolLastUpdateTimeStamp, 3);  

        assertEq(pool.totalPoolRewardsEmitted, 1 ether);
    }

    function testVaultAT03() public {

        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userA has staked into vaultA
             - vault alloc points should be updated: baseVaultALlocPoint dropped, and overwritten w/ userA allocPoints
             - stakedTokens updated
             - vaultIndex updated
             - fees updated
             - rewards updated
        */
        
        assertEq(vaultA.allocPoints, userAPrinciple);
        assertEq(vaultA.stakedTokens, userAPrinciple); 
       
        // indexes
        assertEq(vaultA.accounting.vaultIndex, 1e16); 
        assertEq(vaultA.accounting.vaultNftIndex, 0); 
        assertEq(vaultA.accounting.rewardsAccPerToken, 0); 

        // rewards (from t=2 to t=3)
        assertEq(vaultA.accounting.totalAccRewards, 1e18);               // bonusBall rewards
        assertEq(vaultA.accounting.accNftStakingRewards, 0);               // no tokens staked prior to t=3. no rewwards accrued
        assertEq(vaultA.accounting.accCreatorRewards, 0);                // no tokens staked prior to t=3. therefore no creator rewards       
        assertEq(vaultA.accounting.bonusBall, 1e18); 

        assertEq(vaultA.accounting.claimedRewards, 0); 

    }

    function testUserAT03() public {

        DataTypes.UserInfo memory userA = getUserInfoStruct(vaultIdA, userA);

        /**
            vaultIndex = 1e16

            Calculating userIndex:
             grossUserIndex = 1e16
             totalFees = 0.2e18
             
             userIndex = [1e16 * (1 - 0.2e18) / 1e18] = [1e16 * 0.8e18] / 1e18 = 8e15
        */

        assertEq(userA.stakedTokens, userAPrinciple);

        assertEq(userA.userIndex, 0);   
        assertEq(userA.userNftIndex, 0);

        assertEq(userA.accRewards, 1 ether);  // 1e18: bonusBall received
        assertEq(userA.claimedRewards, 0);

        assertEq(userA.accNftStakingRewards, 0);
        assertEq(userA.claimedNftRewards, 0);
        assertEq(userA.claimedCreatorRewards, 0);
    }
}

//Note: t=04,  
//      userA stakes an nft token into VaultA. 
//      vault multiplier increases; so should allocPoints.
//      rewards emitted frm t=3 to t-4 is allocated to userA only.
//      account for bonusBall, 1st NFT incentive, and token staking rewards
abstract contract StateT04 is StateT03 {
    // 
    function setUp() public virtual override {
        super.setUp();

        vm.warp(4);

        vm.prank(userA);
        stakingPool.stakeNfts(vaultIdA, userA, userANfts);
    }
}

contract StateT04Test is StateT04 {

    function testPoolT04() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            From t=3 to t=4, Pool emits 1e18 rewards
            There is only 1 vault in existence, which receives the full 1e18 of rewards
             - rewardsAccruedPerToken = 1e18 / totalAllocPoints 
                                      = 1e18 / userAPrinciple
                                      = 1e18 / 50e18
                                      = 2e16
             - poolIndex should therefore be updated to 1e16 + 2e16 = 3e16 (index represents rewardsPerToken since inception)

            Calculating index:
            - poolIndex = (eps * timeDelta * precision / totalAllocPoints) + oldIndex
             - eps: 1e18 
             - oldIndex: 1e16
             - timeDelta: 1 seconds 
             - totalAllocPoints: 50e18
            
            - poolIndex = (1e18 * 1 * 1e18 / 50e18 ) + 1e16 = 2e16 + 1e16 = 3e16

            
            multplier = 3
            pool.aLLocPoints = 3 * 50e18 = 150e18 
            
        */

        assertEq(pool.totalAllocPoints, (userAPrinciple * vaultA.multiplier)); 
        assertEq(pool.emissisonPerSecond, 1 ether);

        assertEq(pool.poolIndex, 3e16);
        assertEq(pool.poolLastUpdateTimeStamp, 4);  

        assertEq(pool.totalPoolRewardsEmitted, 2 ether);
    }

    function testVaultAT04() public {

        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userA has staked into vaultA @t=3.
            rewards emitted from t3 to t4, allocated to userA.
             
            rewards & fees:
             incomingRewards = 1e18
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17

             totalAccRewards += incomingRewards = 1e18 + incomingRewards = 1e18 + 1e18 = 2e18
            
             rewardsAccPerToken += incomingRewards - fees / stakedTokens = (1e18 - 2e17)*1e18 / 50e18 = 1.6e16

            multplier = 3
            vault.aLLocPoints = 3 * 50e18 = 150e18 

        */
       
        //uint256 rewardsAccPerToken = (vaultA.accounting.vaultIndex - vaultA.accounting.accNftStakingRewards - vaultA.accounting.accCreatorRewards) / vaultA.stakedTokens;

        // nft section 
        assertEq(vaultA.stakedNfts, 1); 
        assertEq(vaultA.multiplier, 3);
        assertEq(vaultA.accounting.vaultNftIndex, 0);       //no nft staked before: so index 0

        // tokens
        assertEq(vaultA.stakedTokens, userAPrinciple); 
        assertEq(vaultA.allocPoints, userAPrinciple * vaultA.multiplier);

        // token index
        assertEq(vaultA.accounting.vaultIndex, 3e16); 
        assertEq(vaultA.accounting.rewardsAccPerToken, 1.6e16); 

        // rewards 
        assertEq(vaultA.accounting.totalAccRewards, 2e18);               
        assertEq(vaultA.accounting.accNftStakingRewards, 1e17);               // tokens staked. rewards accrued for 1st NFT staker.
        assertEq(vaultA.accounting.accCreatorRewards, 1e17);                      
        assertEq(vaultA.accounting.bonusBall, 1e18); 

        assertEq(vaultA.accounting.claimedRewards, 0); 
    }

    function testUserAT04() public {

        DataTypes.UserInfo memory userA = getUserInfoStruct(vaultIdA, userA);
        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userIndex = vault.accounting.rewardsAccPerToken

            accRewards = bonusBall(t2-t3) + 1e18(t3-t4) 
                       = 1e18 + [1e18 * 0.8]
                       = 1.8e18

            accNftStakingRewards = 1st NFt staking incentive(t3-t4)
                                 = [1e18 * 0.1]
                                 = 1e17
        */

        // nft section 
        assertEq(userA.stakedNfts, 1); 
        assertEq(userA.userNftIndex, 0);

        // tokens
        assertEq(userA.stakedTokens, userAPrinciple);
        assertEq(userA.userIndex, vaultA.accounting.rewardsAccPerToken);   

        // rewards
        assertEq(userA.accRewards, 1.8 ether);  // 1e18: bonusBall received + rewards less of fees
        assertEq(userA.claimedRewards, 0);

        assertEq(userA.accNftStakingRewards, 1e17);
        assertEq(userA.claimedNftRewards, 0);

        assertEq(userA.claimedCreatorRewards, 0);
    }
}

//Note: t=05  
//      userB stakes tokens into VaultA.
//      userB should enjoy a multiplier effect from prior staked NFT - reflected in allocPoints
//      rewards emitted frm t-4 to t-5 is allocated to userA only.
abstract contract StateT05 is StateT04 {

    function setUp() public virtual override {
        super.setUp();

        vm.warp(5);

        vm.prank(userB);
        stakingPool.stakeTokens(vaultIdA, userB, userBPrinciple);
    }
}


contract StateT05Test is StateT05 {

    function testPoolT05() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
        /**
            From t=4 to t=5, Pool emits 1e18 rewards
            There is only 1 vault in existence, which receives the full 1e18 of rewards
             - rewardsAccruedPerToken = 1e18 / totalAllocPoints 
                                      = 1e18 / userAPrinciple * multplier
                                      = 1e18 / (50e18 * 3)
                                      = 6.6666e15
             - poolIndex should therefore be updated to 3e16 + 6.6666e15 = 3.6666e16 (index represents rewardsPerToken since inception)

            Calculating index:
            - poolIndex = (eps * timeDelta * precision / totalAllocPoints) + oldIndex
             - eps: 1e18 
             - oldIndex: 3e16
             - timeDelta: 1 seconds 
             - totalAllocPoints: 150e18
            
            - poolIndex = (1e18 * 1 * 1e18 / 150e18 ) + 3e16 = 6.6666e15 + 3e16 = 3.6666e16
        */

        assertEq(pool.totalAllocPoints, (userAPrinciple + userBPrinciple) * 3); 
        assertEq(pool.emissisonPerSecond, 1 ether);

        assertEq(pool.poolIndex/1e13, 3.666e16/1e13);                 //rounding: recurring decimal
        assertEq(pool.poolLastUpdateTimeStamp, 5);  

        assertEq(pool.totalPoolRewardsEmitted, 3 ether);
    }

    function testVaultAT05() public {

        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userA has staked into vaultA @t=3.
            userB staked at t5, does not accrue any rewards yet.

            rewards emitted from t4 to t5, allocated to userA.
             
            rewards & fees:
             incomingRewards = 1e18
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17
             accNftStakingRewards = 1e18 * 0.1e18 / precision = 1e17

            totalAccRewards += incomingRewards = 1e18 + incomingRewards = 1e18 + 1e18 = 3e18
            accCreatorFee = 1e17 + 1e17 = 2e17
            accNftStakingRewards = 1e17 + 1e17 = 2e17

            rewardsAccPerToken += incomingRewards - fees / stakedTokens = (1e18 - 2e17) * 1e18 / 50e18 = 1.6e16
             rewardsAccPerToken = 1.6e16 + 1.6e16 = 3.2e16

            vaultNftIndex [t4-t5]: nft staked at t4
             nftIndex += (accTotalNFTFee / vault.stakedNfts)
             nftIndex = (1e17 / 1)
                      = 1e17

            !!!
            poolIndex = vaultIndex = 3.6666e16 
             -> recurring decimal, source of rounding issues within rewards, fee calcs and nftIndex.
        */
       

        // nft section 
        assertEq(vaultA.stakedNfts, 1); 
        assertEq(vaultA.multiplier, 3);
        assertEq(vaultA.accounting.vaultNftIndex/1e13, 9.999e16/1e13);      // calculated val: 1e17 

        // tokens
        assertEq(vaultA.stakedTokens, (userAPrinciple + userBPrinciple)); 
        assertEq(vaultA.allocPoints, (userAPrinciple + userBPrinciple) * vaultA.multiplier);

        // token index
        assertEq(vaultA.accounting.vaultIndex/1e13, 3.666e16/1e13); 
        assertEq(vaultA.accounting.rewardsAccPerToken/1e13, 3.199e16/1e13);         // calculated val: 3.2e16

        // rewards 
        assertEq(vaultA.accounting.totalAccRewards/1e15, 2.999e18/1e15);                 // calculated: 3e18
        assertEq(vaultA.accounting.accNftStakingRewards/1e14, 1.999e17/1e14);            // calculated val: 2e17
        assertEq(vaultA.accounting.accCreatorRewards/1e14, 1.999e17/1e14);               // calculated val: 2e17       
        assertEq(vaultA.accounting.bonusBall, 1e18); 

        assertEq(vaultA.accounting.claimedRewards, 0); 
    }

    function testUserBT05() public {

        DataTypes.UserInfo memory userB = getUserInfoStruct(vaultIdA, userB);
        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        // userA is not updated! check userB!

        /**
            userIndex = vault.accounting.rewardsAccPerToken

            userNftIndex = vaultA.accounting.vaultNftIndex

            accRewards = bonusBall(t2-t3) + 1e18(t3-t4) + 1e18(t4-t5)  | [bonusBall + rewards less of fees]
                       = 1e18 + [2e18 * 0.8]
                       = 2.6e18

            accNftStakingRewards = 1e17 + [1e18 * 0.2]                 | 1st NFT staker incentive + nft fee
                                 = 3e17
        */

        // nft section 
        assertEq(userB.stakedNfts, 0); 
        assertEq(userB.userNftIndex, vaultA.accounting.vaultNftIndex);

        // tokens
        assertEq(userB.stakedTokens, userBPrinciple);
        assertEq(userB.userIndex, vaultA.accounting.rewardsAccPerToken);   

        // rewards
        assertEq(userB.accRewards, 0 ether);  
        assertEq(userB.claimedRewards, 0);

        assertEq(userB.accNftStakingRewards, 0);
        assertEq(userB.claimedNftRewards, 0);

        assertEq(userB.claimedCreatorRewards, 0);
    }
}

