# Problems

## LZ

- blocking or nonblocking
- what if txn fails on dstChain: failure remedy, mitigation, automatic relies
- V1 vs/or V2
- which V2 lib/repo?
- postdeployment: monitoring dashboard where we can track metrics, health of system and so forth.

## Vault creation period

120 days from deployment vaults can be created.
lastDay = startDate + 120 days.
vault creation check: if vaultStart + duration exceed lastDay, reject creation
> rewards are emitted for 120 days

## Calculating rewards and fees

(Rewards and fees accounting)
- need to track creator and NFT fees.
- creator and NFT fees may vary.
- how to track rewards to users and fees in a varying manner


## StakingPool Misc

- vaults must be updated via script before `latestPoolTimestamp > vault.endTime`.
- once poolTimestamp exceeds vault.endTime, the vault cannot be updated any more.
- 24 hours before all vaults ought to be updated, just in case txn fails or due to sheer quantity.

## BATCHING

how to batch?

# FOR CLARIFICATION

## AccessControls

- owner or RBAC?
- https://blog.openzeppelin.com/admin-accounts-and-multisigs
- https://www.rareskills.io/post/openzeppelin-ownable2step
- https://coinsbench.com/how-to-safely-manage-smart-contract-ownership-cc6acbbfcc8f?gi=2ca3c9fd515c



remove all instances ofthe ladele
- Uniswap Router and the Compound Bulker.

restrict fns on stakingPoolL: onlyAdmin
users must user router to publicly call 


1. change vaultBaseAllocPoints to immutable
2. refactor testing to be modular?


realm points?