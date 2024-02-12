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
        assertEq(poolLastUpdateTimeStamp, 0);
        assertEq(totalPoolRewards, rewards);
        assertEq(totalPoolRewardsEmitted, 0);

        // check rewards vault
        assertEq(rewardsVault.totalVaultRewards(), rewards);

        // check time
        assertEq(block.timestamp, 0);
    }
}

//Note: Pool deployed but not active yet. t = 0.
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
        
        (bytes32 vaultId_, address creator,,,,,,, ) = stakingPool.vaults(vaultId);

        assertEq(vaultId_, bytes32(0));
        assertEq(creator, address(0));   
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

//Note: t=02, Vault created. 
//      but no staking done. 
//      vault will accrued rewards towards bonusBall
abstract contract StateT02 is StateT01 {

    bytes32 public vaultIdA;

    function setUp() public virtual override {
        super.setUp();

        vm.warp(2);

        // vault params
        uint8 salt = 1;
        uint256 creatorFee = 0.10 * 1e18;
        uint256 nftFee = 0.10 * 1e18;

        // vault Id: 0xaf70b64da6263772d20ce496dc028133986416edb1c1bab48e1021ef72b16b3f
        vaultIdA = generateVaultId(salt, userA);

        // create vault
        vm.prank(userA);       
        stakingPool.createVault(userA, salt, DataTypes.VaultDuration.THIRTY, creatorFee, nftFee);
    }
    
    function generateVaultId(uint8 salt, address onBehalfOf) public view returns (bytes32) {
        return bytes32(keccak256(abi.encode(onBehalfOf, block.timestamp, salt)));
    }
}

//Note: t=02, Pool deployed and active. userA and userB stake.
contract StateT02Test is StateT02 {

    function testNewVault() public {
        // check vault
        (bytes32 vaultId, address creator, DataTypes.VaultDuration duration_, uint256 endTime, uint256 multiplier,
        uint256 allocPoints, uint256 stakedNfts, uint256 stakedTokens, DataTypes.VaultAccounting memory vaultAccounting) = stakingPool.vaults(vaultIdA);

        assertEq(vaultIdA, vaultId);
        assertEq(userA, creator);
        assertEq(uint8(DataTypes.VaultDuration.THIRTY), uint8(duration_));
        assertEq(block.timestamp + 30 days, endTime);

        assertEq(1, multiplier);
        assertEq(100, allocPoints);     //baseAllocPoints
        assertEq(0, stakedNfts);
        assertEq(0, stakedTokens);

    }

    //should be no rewards to claim
    function testCanStake() public {
        vm.prank(userA);
        stakingPool.stakeTokens(vaultIdA, userA, 1e18);
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