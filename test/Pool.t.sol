// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2, stdStorage, StdStorage} from "forge-std/Test.sol";

// my contracts
import {Pool} from "../src/Pool.sol";
import {RewardsVault} from "../src/RewardsVault.sol";

import {MocaToken, ERC20} from "../src/MocaToken.sol";
import {MocaNftToken} from "../src/MocaNftToken.sol";

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
    MocaNftToken public mocaNFT;      
    
    //address public REALM_POINTS;
    
    // stakingPool constructor data
    uint256 public startTime;           
    uint256 public duration;    
    uint256 public rewards;            
    string public name; 
    string public symbol;
    address public owner;
    uint256 public constant vaultBaseAllocPoints = 100 ether;    

    // testing data
    address public userA;
    address public userB;
    address public userC;
   
    uint256 public userAPrinciple;
    uint256 public userBPrinciple;
    uint256 public userCPrinciple;

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
        mocaNFT = new MocaNftToken("stkMocaNFT", "stkMocaNFT");

        //IERC20 rewardToken, address moneyManager, address admin
        rewardsVault = new RewardsVault(IERC20(mocaToken), owner, owner);
        // rewards for emission
        mocaToken.mint(address(rewardsVault), rewards);  

        // init: GovernorAlpha::proposalCount() = 0
        // change to 1, so that GovernorBravo not active test clears
        stdstore
        .target(address(rewardsVault))
        .sig(rewardsVault.totalVaultRewards.selector) 
        .checked_write(rewards);


        // IERC20 stakedToken, IERC20 rewardToken, address realmPoints, address rewardsVault, uint128 startTime_, uint128 duration, uint128 rewards, 
        // string memory name, string memory symbol, address owner
        stakingPool = new Pool(IERC20(mocaToken), IERC20(mocaToken), address(0), address(rewardsVault), startTime, duration, rewards, "stkMOCA", "stkMOCA", owner);

        //mint tokens to users
        mocaToken.mint(userA, userAPrinciple);
        mocaToken.mint(userB, userBPrinciple);
        mocaToken.mint(userC, userCPrinciple);
      

        vm.stopPrank();


        // approvals for receiving tokens for staking
        vm.prank(userA);
        mocaToken.approve(address(stakingPool), userAPrinciple);

        vm.prank(userB);
        mocaToken.approve(address(stakingPool), userBPrinciple);
        assertEq(mocaToken.allowance(userB, address(stakingPool)), userBPrinciple);

        vm.prank(userC);
        mocaToken.approve(address(stakingPool), userCPrinciple);
        
        // approval for issuing reward tokens to stakers
        vm.prank(address(rewardsVault));
        mocaToken.approve(address(stakingPool), rewards);


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
            ,uint256 stakedNfts, uint256 stakedTokens, uint256 allocPoints, 
            uint256 userIndex, uint256 userNftIndex,
            uint256 accRewards, uint256 claimedRewards,
            uint256 accNftBoostRewards, uint256 claimedNftRewards,
            uint256 claimedCreatorRewards

        ) = stakingPool.users(user, vaultId);

        DataTypes.UserInfo memory userInfo;

        {
            //userInfo.vaultId = vaultId_;
        
            userInfo.stakedNfts = stakedNfts;
            userInfo.stakedTokens = stakedTokens;
            userInfo.allocPoints = allocPoints;

            userInfo.userIndex = userIndex;
            userInfo.userNftIndex = userNftIndex;

            userInfo.accRewards = accRewards;
            userInfo.claimedRewards = claimedRewards;

            userInfo.accNftBoostRewards = accNftBoostRewards;
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

        // vault Id: 0xaf70b64da6263772d20ce496dc028133986416edb1c1bab48e1021ef72b16b3f
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

        assertEq(creatorFeeA + nftFeeA, vaultA.accounting.totalFees);
        assertEq(creatorFeeA, vaultA.accounting.creatorFee);
        assertEq(nftFeeA, vaultA.accounting.creatorFee);

        assertEq(0, vaultA.accounting.totalAccRewards);
        assertEq(0, vaultA.accounting.accNftBoostRewards);
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

        // rewards (from t=2 to t=3)
        assertEq(vaultA.accounting.totalAccRewards, 1e18);               // bonusBall rewards
        assertEq(vaultA.accounting.accNftBoostRewards, 0);               // no tokens staked prior to t=3. no rewwards accrued
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
        assertEq(userA.allocPoints, userAPrinciple);

        assertEq(userA.userIndex, 8e15);   // matching poolIndex
        assertEq(userA.userNftIndex, 0);

        assertEq(userA.accRewards, 1 ether);  // 1e18: bonusBall received
        assertEq(userA.claimedRewards, 0);

        assertEq(userA.accNftBoostRewards, 0);
        assertEq(userA.claimedNftRewards, 0);
        assertEq(userA.claimedCreatorRewards, 0);
    }
}

//Note: t=04,  
//      userB stakes into VaultA. 
//      rewards emitted frm t=3 to t-4 is allocated to userA only.
abstract contract StateT04 is StateT03 {
    // 
    function setUp() public virtual override {
        super.setUp();

        vm.warp(4);

        vm.prank(userB);
        stakingPool.stakeTokens(vaultIdA, userB, userBPrinciple);
    }
}

contract StateT04Test is StateT04 {

    // check tt staking was received and recorded correctly
    // check pool, vault and userInfo

    function testPoolT04() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
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
        */

        assertEq(pool.totalAllocPoints, userAPrinciple + userBPrinciple); 
        assertEq(pool.emissisonPerSecond, 1 ether);

        assertEq(pool.poolIndex, 3e16);
        assertEq(pool.poolLastUpdateTimeStamp, 4);  

        assertEq(pool.totalPoolRewardsEmitted, 2 ether);
    }

    function testVaultAT04() public {

        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userA has staked into vaultA @t=3. userB has staked into vaultA @t=4.
            rewards emitted from t3 to t4, allocated to userA.
             - vault alloc points should be updated: sum of userA and userB principles (since multplier is 1)
             - stakedTokens updated
             - vaultIndex updated
             - fees updated
             - rewards updated
            
            rewards & fees:
             incomingRewards = 1e18
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17

             totalAccRewards += incomingRewards = 1e18 + incomingRewards = 1e18 + 1e18 = 2e18
        */
       
        assertEq(vaultA.allocPoints, userAPrinciple + userBPrinciple);
        assertEq(vaultA.stakedTokens, userAPrinciple + userBPrinciple); 
       
        // indexes: in-line with poolIndex
        assertEq(vaultA.accounting.vaultIndex, 3e16); 
        assertEq(vaultA.accounting.vaultNftIndex, 0); 

        // rewards (from t=3 to t=4)
        assertEq(vaultA.accounting.totalAccRewards, 2e18);               
        assertEq(vaultA.accounting.accNftBoostRewards, 1e17);               // tokens staked. rewards accrued for 1st staker.
        assertEq(vaultA.accounting.accCreatorRewards, 1e17);                // no tokens staked prior to t=3. therefore no creator rewards       
        assertEq(vaultA.accounting.bonusBall, 1e18); 

        assertEq(vaultA.accounting.claimedRewards, 0); 

    }

    // can't test A cos, A is stale. no action taken.

    function testUserBT04() public {

        DataTypes.UserInfo memory userB = getUserInfoStruct(vaultIdA, userB);

        /**
            Rewards:
             userB should have accrued 0 rewards. just staked at t4.

            Calculating userIndex:
             vaultIndex = 3e16
             grossUserIndex = 3e16
             totalFees = 0.2e18
             
             userIndex = [3e16 * (1e18 - 0.2e18) / 1e18] = [3e16 * 0.8e18] / 1e18 = 2.4e16

        */

        assertEq(userB.stakedTokens, userBPrinciple);
        assertEq(userB.allocPoints, userBPrinciple);

        assertEq(userB.userIndex, 2.4e16);   
        assertEq(userB.userNftIndex, 0);

        assertEq(userB.accRewards, 0 ether);  
        assertEq(userB.claimedRewards, 0);

        assertEq(userB.accNftBoostRewards, 0);
        assertEq(userB.claimedNftRewards, 0);
        assertEq(userB.claimedCreatorRewards, 0);
    }
}

//Note: t=05,  
//      both user have staked into vaultA at different times and sizes.
//      rewards emitted frm t=3 to t-4 is allocated to userA only.
//      rewards emitted frm t=4 to t=5 is allocated to both users, proportionally. 
abstract contract StateT05 is StateT04 {
    function setUp() public virtual override {
        super.setUp();

        vm.warp(5);

        vm.prank(userA);
        stakingPool.claimRewards(vaultIdA, userA);

        //vm.prank(userB);
        //stakingPool.claimRewards(vaultIdA, userB);
    }
}

contract StateT05Test is StateT05 {

    function testPoolT05() public {

        DataTypes.PoolAccounting memory pool = getPoolStruct();
        /**
            From t=4 to t=5, Pool emits 1e18 rewards
            There is only 1 vault in existence, which receives the full 1e18 of rewards
             - rewardsAccruedPerToken = 1e18 / totalAllocPoints 
                                      = 1e18 / userAPrinciple + userBPrinciple
                                      = 1e18 / 80e18
                                      = 1.25e16
             - poolIndex should therefore be updated to 3e16 + 1.25e16 = 4.25e16 (index represents rewardsPerToken since inception)

            Calculating index:
            - poolIndex = (eps * timeDelta * precision / totalAllocPoints) + oldIndex
             - eps: 1e18 
             - oldIndex: 3e16
             - timeDelta: 1 seconds 
             - totalAllocPoints: 80e18
            
            - poolIndex = (1e18 * 1 * 1e18 / 80e18 ) + 3e16 = 1.25e16 + 3e16 = 4.25e16
        */

        assertEq(pool.totalAllocPoints, userAPrinciple + userBPrinciple); 
        assertEq(pool.emissisonPerSecond, 1 ether);

        assertEq(pool.poolIndex, 4.25e16);
        assertEq(pool.poolLastUpdateTimeStamp, 5);  

        assertEq(pool.totalPoolRewardsEmitted, 3 ether);
    }

    function testVaultAT05() public {

        DataTypes.Vault memory vaultA = getVaultStruct(vaultIdA);

        /**
            userA has staked into vaultA @t=3. userB has staked into vaultA @t=4.
            rewards emitted from t3 to t4, allocated to userA.
            rewards emitted frm t=4 to t=5 is allocated to both users, proportionally. 
             - vault alloc points should be updated: sum of userA and userB principles (since multplier is 1)
             - stakedTokens updated
             - vaultIndex updated
             - fees updated
             - rewards updated
            
            rewards & fees:
             incomingRewards = 1e18
             accCreatorFee = 1e18 * 0.1e18 / precision = 1e17
             accNftBoostRewards = 1e18 * 0.1e18 / precision = 1e17
             
             accCreatorFee = 1e17 + 1e17 = 2e17
             accNftBoostRewards = 1e17 + 1e17 = 2e17
             totalAccRewards = totalAccRewards + incomingRewards = 2e18 + 1e18 = 3e18
        */
       
        assertEq(vaultA.allocPoints, userAPrinciple + userBPrinciple);
        assertEq(vaultA.stakedTokens, userAPrinciple + userBPrinciple); 
       
        // indexes: in-line with poolIndex
        assertEq(vaultA.accounting.vaultIndex, 4.25e16); 
        assertEq(vaultA.accounting.vaultNftIndex, 0); 

        // rewards (from t=3 to t=4)
        assertEq(vaultA.accounting.totalAccRewards, 3e18);               
        assertEq(vaultA.accounting.accNftBoostRewards, 2e17);               // tokens staked. rewards accrued for 1st staker.
        assertEq(vaultA.accounting.accCreatorRewards, 2e17);                // no tokens staked prior to t=3. therefore no creator rewards       
        assertEq(vaultA.accounting.bonusBall, 1e18); 

        assertEq(vaultA.accounting.claimedRewards, 2.3e18); 

    }


    function testUserAT05() public {

        DataTypes.UserInfo memory userA = getUserInfoStruct(vaultIdA, userA);

        /**
            Rewards:
             userA should have accrued 
             bonusBall: 1e18 
             rewards from t3 to 4 = 1e18 * 0.8 = 8e17
             rewards from t3 to 4 = 1e18 * 0.8 * 50/80 = 5e17
            
            totalRewards = 2.3e18

            Calculating userIndex:
             vaultIndex = 4.25e16
             grossUserIndex = 4.25e16
             totalFees = 0.2e18
             
             userIndex = [4.25e16 * (1e18 - 0.2e18) / 1e18] = [4.25e16 * 0.8e18] / 1e18 = 3.4e16

        */

        assertEq(userA.stakedTokens, userAPrinciple);
        assertEq(userA.allocPoints, userAPrinciple);

        assertEq(userA.userIndex,  3.4e16);   // matching poolIndex
        assertEq(userA.userNftIndex, 0);

        assertEq(userA.accRewards, 2.3e18);  // 1e18: bonusBall received
        assertEq(userA.claimedRewards, 2.3e18);

        assertEq(userA.accNftBoostRewards, 0);
        assertEq(userA.claimedNftRewards, 0);
        assertEq(userA.claimedCreatorRewards, 0);
    }

}


/**
    Scenario: Linear Mode

    ** Pool info **
    - stakingPool startTime: t1
    - stakingStart: t2
    - stakingPool endTime: t12
    - duration: 11 seconds
    - emissionPerSecond: 1e18 (1 token per second)
    
    ** Phase 1: t0 - t1 **
    - stakingPool deployed
    - stakingPool inactive

    ** Phase 1: t1 - t2 **
    - stakingPool active
    - no stakers
    - 1 reward emitted in this period, that is discarded.

    ** Phase 1: t2 - t11 **
    - userA and userB stake at t2
    - 9 rewards emitted in period

        At t2: 
        userA and userB stake all of their principle
        - userA principle: 50 tokens (50e18)
        - userB principle: 30 tokens (30e18)

        totalStaked at t2 => 80 tokens

        At t11:
        calculating rewards:
        - timeDelta: 11 - 2 = 9 seconds 
        - rewards emitted since start: 9 * 1 = 9 tokens
        - rewardPerShare: 9e18 / 80e18 = 0.1125 

        rewards earned by A: 
        A_principle * rewardPerShare = 50 * 0.1125 = 5.625 rewards

        rewards earned by B: 
        B_principle * rewardPerShare = 30 * 0.1125 = 3.375 rewards

    
    ** Phase 1: t11 - t12 **
    - userC stakes
    - final reward of 1 reward token is emitted at t12.
    - Staking ends at t12
    
        At t11:
        userC stakes 80 tokens
        
        - only 1 token left to be emitted to all stakers

        Principle staked
        - userA: 50 + 5.625 = 55.625e18
        - userB: 30 + 3.375 = 33.375e18
        - userC: 80e18

        totalStaked at t10 => 169e18 (80 + 9 + 80)tokens

        At12:
        calculating earned:
        - timeDelta: 12 - 11 = 1 second
        - rewards emitted since LastUpdateTimestamp: 1 * 1 = 1 token
        - rewardPerShare: 1e18 / 160e18 = 0.00625

        userA additional rewards: 50 * 0.00625 = 0.3125
        userA total rewards: 5.625 + 0.3125 = 5.9375

        userB additional rewards: 30 * 0.00625 = 0.1875
        userB total rewards: 3.375 + 0.1875 = 3.5625

        userC additional rewards: 80 * 0.00625 = 0.5
        userC total rewards: 0 + 0.5 = 0.5

*/