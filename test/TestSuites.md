# Test Suites Breakdown

## Basic30.t.sol

- t0: Pool Deployed
- t1: Staking startTime: staking can begin
- t2: vaultA created, by userA
- t3: userA stakes in full (beneficiary of BonusBall)
- t4: userB stakes in full
- t5: userA and userB claim rewards
-- userA accrues rewards from t3 to t5
-- userB accrues rewards from t4 to t5
- t6: userA claims creatorFee reward 
-- (partial claim as the vault has not matured)
- t7: vaultC created, by userC
- t8: userC stakes half of principal (beneficiary of BonusBall)
- t9: userC stakes half of principal (user C is now full committed)
- t10: userC claims rewards
- t2,592,002: VaultAEnds. userA claims rewards
- t2,592,003: 1 second after vaultA has ended. 
-- check tt vaultA is not updated, although Pool is.
- t2,592,007: vaultC ends. 
-- check unstaking and rewards

> need to check token balances in the intermediate steps

## Basic30NFT.t.sol

- t0: Pool Deployed
- t1: Staking startTime: staking can begin
- t2: vaultA created, by userA
- t3: userA stakes in full (beneficiary of BonusBall)
- t4: userA stakes nft
- t5: userB stakes nft
- t6: userB staked tokens in full
- t7: userC creates vaultC
- t8: userC stakes nft
- t9: userC stakes tokens
- t10: check updated vault
- t_StateVaultAEndTime: vaultA ends (userC cannot stake nft once vault ends)
- t_: vaultC end




stake before
stake during
stake after : should fail

userA: stake 1 nft in vaultA
...
userB: stake 1 nft in vaultA
...
create vaultC
...
userC: stake 1 nft in vaultC

### need to test double staking of nft

#### does nft multiplier affect vaultBaseTokens?

- no
- nft effects only work on stakedTokens
- once vault has tokens are staked, nftFee is levied
- nftIndex only starts incrementing once there are stakedTokens

 if user stakes nft onto an empty vault, the multiplier will increase.
 but the multiplier effect is not applied unto the vault as they are no stakedTokens
 the vault continues to operate w/ vaultBaseAllocPoints (virtualShares) - which is not boosted by the nft multiplier.


 nft staker can staked into a non-nft pool at the very last second to grab incentive