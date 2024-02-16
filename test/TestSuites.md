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

stake before
stake during
stake after : should fail
