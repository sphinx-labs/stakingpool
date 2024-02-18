# Staking Pool with vaults

Staking pool with a twist.
Pool allows for creation of "sub-accounts" a.k.a vaults. Each vault has its own unique set of fees, as set by the vault creator.
Users can will then seek to stake in whichever vault appeals to them, based on the fees levied.

In short, users stake into vaults. The pool emits a certain amount of token rewards per second, which is distributed across all created vaults proportionally, based upon their allocPoints.
Vaults have differing allocPoints as a consequence of their duration and number of NFTs staked in them.

## Pool

Pool has a specified startTime and endTime. Vaults created must start and end within this period.

- `startTime` allows for Pool to be deployed in advance, and for staking to begin at some future time as defined by it.
- Users cannot interact with the Pool before the `startTime` - txns will revert.
- Users cannot create vaults or engage in any kind of staking before `startTime` or after `endTime`.
- Users **can** unstake and claim any rewards or fees after a vault or pool ends.

> Users are expected to interact with the Router, not the stakingPool contract directly.
> Need to build router next

## Pool and Reward Emission

The pool emits a constant amount of reward tokens per second as defined in `pool.emissisonPerSecond`.
This gets proportionally split across all the vaults as per their weighage against `pool.totalAllocPoints`.

`pool.totalAllocPoints` is the sum of all the allocPoints of all the vaults created.

## Vaults

Only a user that meets certain RP requirements, can create a vault.
> How to call RP contract? smlj signature

A vault must end before the pool's endTime; else it cannot be created.

There are 3 types of vaults:

- 30 day
- 60 day
- 90 day

Longer duration vaults (60/90), have a multiplier effect to the rewards they accrue.
Meaning to say, a basic 30-day vault will have lower allocPoints compared to the basic 60-day vault.
The basic 90-day vault will have the highest allocPoints of all 3.

This is to incentivize users to create longer-term vaults and stake into them.

When a user wishes to create a vault, he must specify the `creatorFeeFactor` and `totalNftFeeFactor`.
The rewards accrued by a vault are subject to both these fees. The fee factors are expressed as percentages.

Users that stake in a vault earn rewards less of the fees levied.

> Limits on feeFactors?

## Vault Fees

The vault creator earns the creator fee, while the rewards accrued from the `totalNftFeeFactor` is split amongst the various nft stakers.
The total rewards earned from levying said fees are reflected in the vault.accounting struct as:

- accCreatorRewards             (goes to vault creator)
- accNftStakingRewards          (split amongst nft stakers)

Since we need to accommodate the fact that nfts could be staked at different times through the lifecycle of a vault, we use `vaultNftIndex` together with `userNftIndex` to accurately award nft staking rewards to said users.

## Staking

Users are expected to stake Moca tokens into a vault to earn staking rewards.

- Once staked, users can only unstake their principal once the vault has matured.
- However, users are free to claim rewards and fees before the vault has matured, and restake them - in any vault of choice.

> There are staking limits based on RP now? need to confirm before implementing

## Staking multiplier and allocPoints

A vault's allocPoints is determined by: `stakedTokens * multiplier`

This means that if the vault's multiplier is > 1, 

Additionally, they can stake Moca NFTs to "boost" the rewards earned by the vault.
Each nft staked increases the vault multiplier by a fixed amount as defined by the constant `nftMultiplier`.

> Vault multiplier accounting needs to be confirmed. Are we doubling the entire amount or just the base?
> Will it be an additive series or multiplicative?

## BonusBall and 1st NFT incentive


## 

pool -> vault
- operate on allocPOints
- vault.allocPoints

:: vault.allocPoints::
- updated in create, based on duration
- update in stake, based on stake amount: incomingAllocPoints = (amount * vault.multiplier)

internal to a vault
- can operate on token values
- convert vaultIndex(rewardsAccPerAllocPoint) to vaultIndex(rewardsAccPerToken)
- userIndex(rewardsAccPerToken)

## Dependencies

forge install  openzeppelin/openzeppelin-contracts@v5.0.1

## AllocPoints

1 allocPoint = "1 token"

cos of multiplier/boosting effects.

## Indexes

### wtf index

poolIndex  = accRewardsPerAllocPoint

### Pool Index

poolIndex reflects the rewardsAccruedPerAllocPoint since inception.
poolIndex will be updated when either one of the following changes:
    1. totalAllocPoints
    2. poolEmissisonPerSecond

totalAllocPoints is incremented on vault creation and decremented on vault maturity.
> need a script to update totalAllocPoints to prevent dilution, specific on vault mautiries

### Pool Index and Vault Index

Vaults can be created on an ad-hoc basis during the staking period. Upon creation, vaultIndex == poolIndex, to disregard all prior accrued rewards.

Therefore, the rewards captured by a specific vault is defined as the delta between its initial vaultIndex value and final value at maturity.

Each time a vault experiences a state-change (stake, claim), rewards earned from lastUpdateTimestamp till now are booked into accRewards.

### Vault Index and User Index

Similar to vaultIndex, the userIndex reflects the rewards captured by a specific user, for a specific vault, based on their duration of staking exposure.

I.e. Upon staking, userIndex is initially set to equal vaultIndex at the time of staking. This is to negate all prior earned rewards.
Subsequently, each time the user engages in state-changing behaviour, his prior rewards up till that point is calculated and booked into accRewards.

### Fees and rewards

The userIndex is net of fees.
vaultIndex * fees(0.80) = userIndex.

I am applying fees onto vaultIndex - which is denominated in 18 dp precision, as defined by our Moca token. So sensible to stick with that.

## NftIndex and rewards

We want to incentivize users to stake NFTs in pools that do not have any staked in them.

At a vault level:

- If vault has tokens staked, apply NFT fee.
- In vault, `accNftBoostRewards` is incremented reflected the fee cut on the incoming rewards for tt period.
- if there are stakedNfts as well, `vaultNftIndex` is incremented, reflecting rewardsAccPerNFT.

This means tt from 1st token staked till 1st nft staked:

- accNftBoostRewards is incremented
- vaultNftIndex is not.

vaultNftIndex only begins to increment from 0, after the 1st nft is staked.
Therefore, the initial period during which only the `accNftBoostRewards` increments while vaultNftIndex does not, is reflective of the incentive to the 1st person to stake their NFT into the vault.

Similar concept to bonusBall - 1st mover advantage.

Subsequently, nftStakingRewards are calculated as per the nftIndex which can accommodate calculating the rewards split across different nft staking actions by different users across multiple points in time.

## Contingencies

Assuming something untoward happens, the primary concern is securing users' staked funds and to immediately pause emission of rewards.

Calling `pause` achieves this and allows assessment of the situation to determine the best course of remediation action.

The following would be the remediation actions available:
    1. allow users to only withdraw principal staked assets (unclaimed rewards forgone)
    2. allow users to withdraw both principal and unclaimed rewards accrued to date.

Given that exploiting the rewards emissions mechanism is one of the highest probability attack vectors, it is sensible to follow the approach as laid out in option 1. Subsequently, a new pool and be deployed for continuation.

Thus the contingency plan will be as follows:

1. `pause`
2. assess
3. If sitrep deems a valid attack, call `freeze`. Else `unpause` for continuation.
4. On `freeze`: user can withdraw staked assets via `emergencyExit`.
5. If the scope of attack somehow incapacitates the withdrawal of principal assets, we would need an admin emergency function: `recoverERC20`, `recoverNft`--> (legal will have issues?)

>Note that pool and vault indexes will NOT be updated to brought in-line with the present time.  - in the event of an emergency.

### Unpausing for continuation

Assuming false positive:

1. `unpause`
2. `updateVault`: some random vault, poolIndex will also be updated.

In this flow, operation continues as per normal. The time delay between pausing and unpausing will not affect(truncate) the rewards emitted by the pool. This is due to the manner in which the poolIndex is  updated via timeDelta.

The only material impact would be that during the paused period users cannot claim rewards and stake assets. Essentially, a 'lost' period of activity.

## Gas Opt

No time.
