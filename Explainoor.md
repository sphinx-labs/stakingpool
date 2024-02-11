# Explainoooor

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

The userIndex is nett of fees.
vaultIndex * fees(0.80) = userIndex.

I am applying fees onto vaultIndex - which is denominated in 18 dp precision, as defined by our Moca token. So sensible to stick with that.

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