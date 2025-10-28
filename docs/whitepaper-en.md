# PeaceDAO Donation Flow (Community Manager Update)

## Roles
- **Verifier**: Confirms that proof-of-donation evidence is valid. Receives a micro-reward per approved donation.
- **Community Manager**: DAO-appointed steward who stakes **≥ 500,000 $世界和平** for a fixed term. Up to **3** can be active at once.
- **Operations (Founder)**: Receives the remaining operating budget after rewards are paid.
- **Beneficiary**: Always receives **90%** of each approved donation.

## Stake & Eligibility
- Managers must hold and stake at least **500,000 $世界和平** before appointment.
- Staked tokens are locked until the term end specified in the appointment proposal.
- DAO proposals appoint/remove managers and can adjust the maximum count (capped by the PeaceFund deployment parameter).

## Donation Distribution
Given a donation amount `D`:
1. `beneficiary = D * 90%`
2. `ops = D * 10%`
3. `verifierReward = D * 0.005%`
4. `managerPool = D * 0.005%`
5. `opsRemainder = ops - verifierReward - managerPool`

`managerPool` is split equally among the active managers; any rounding dust remains with operations.

### Worked Example (100 BNB Donation, 2 Managers)
- Beneficiary: `90.0000 BNB`
- Verifier: `0.0050 BNB`
- Managers: `0.0050 BNB` → `0.0025 BNB` each
- Operations: `9.9900 BNB`

## Contract Hooks
- `PeaceFund.executeApprovedDonation` orchestrates the split and emits `DonationExecuted`.
- `PeaceDAO.appointManagers/removeManagers` manages roster + staking, syncing active managers to the fund.
- `PeaceVerify.submitVerification` registers the verifier address used for payouts.
