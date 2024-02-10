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
