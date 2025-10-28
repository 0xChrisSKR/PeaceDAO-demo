# PeaceDAO Whitepaper v2 (Sync Draft)

## Abstract
PeaceDAO demonstrates a BNB-backed public treasury that is governed by a role-tiered ERC-20 token (`$世界和平`). Token balances unlock speaking, voting, and proposal rights while leaving donations denominated strictly in BNB. This document synchronizes the governance, treasury, and integration design that underpins the demo implementation so contributors have a single canonical source of truth.

## Motivation
- **Trust breakdown in public chats:** Open communities suffer from identity spoofing and social engineering. Token-gated access enforces verifiable roles before a member can influence decisions or treasury flows.
- **Transparent public good funding:** BNB donations move through a dedicated treasury contract that executes transfers only when a passed on-chain proposal authorizes them.
- **Binance ecosystem alignment:** The demo targets Binance Web3 wallet users and showcases infrastructure Binance engineers can evaluate for production adoption.

## Governance Stack Overview
PeaceDAO aligns three core contracts and off-chain tooling to deliver verifiable governance:

1. **PeaceGate** — assigns roles based on token balances and optional blacklist controls. `roleOf` outputs READER, VOTER, or PROPOSER tiers that map to chat, voting, and proposal creation privileges.【F:contracts/PeaceGate.sol†L25-L63】
2. **PeaceDAO** — manages proposals, voting windows, quorum checks, and refunds the proposer stake once voting finalizes. Passing proposals can trigger BNB disbursements via the treasury contract.【F:contracts/PeaceDAO.sol†L31-L134】【F:contracts/PeaceDAO.sol†L160-L169】
3. **PeaceFund** — holds donated BNB and only releases funds when instructed by the DAO contract, emitting transparent events for auditing.【F:contracts/PeaceFund.sol†L5-L59】

A reference front-end or bot queries these contracts to enforce chat roles (Collab.Land, Guild.xyz) and display treasury balances.

## Token Economics & Roles
- **Token utility:** `$世界和平` is strictly for identity and governance. Members spend BNB for donations; token balances determine privileges.
- **Default thresholds:** Read at `1`, vote at `10`, propose at `100` tokens; operators can raise thresholds to 100 / 200,000 / 1,000,000 (as demonstrated in the demo README) for production-scale gating.【F:contracts/PeaceGate.sol†L34-L55】【F:README.md†L8-L55】
- **Blacklist control:** PeaceGate permits removing malicious actors without slashing holdings, preserving treasury fairness.【F:contracts/PeaceGate.sol†L56-L63】

## Proposal Lifecycle
1. **Preparation:** A PROPOSER stakes `stakeAmount` tokens (default 1,000,000 units adjusted by token decimals).【F:contracts/PeaceDAO.sol†L43-L78】
2. **Creation:** Proposal metadata includes a title, reason, destination address, and requested BNB amount. Voting starts after a configurable delay and runs for the configured block window.【F:contracts/PeaceDAO.sol†L79-L117】
3. **Voting:** Eligible voters cast weighted votes proportional to their token balance. Double voting is prevented via per-proposal tracking.【F:contracts/PeaceDAO.sol†L118-L149】
4. **Execution:** If quorum and majority conditions pass, PeaceFund transfers the requested BNB. Regardless of outcome, the proposer’s stake is refunded exactly once.【F:contracts/PeaceDAO.sol†L150-L169】

## Treasury Model
- **BNB-only custody:** PeaceFund accepts donations via direct transfers or the `donate()` function, emitting events for observers.【F:contracts/PeaceFund.sol†L23-L39】
- **DAO-controlled disbursements:** Only the DAO address can call `transferNative`, ensuring proposal execution is the single path for spending.【F:contracts/PeaceFund.sol†L40-L59】
- **Operational flexibility:** Ownership can be transferred to a multisig or DAO-controlled timelock after deployment, aligning with Binance security expectations.【F:contracts/PeaceFund.sol†L9-L22】【F:contracts/PeaceFund.sol†L52-L59】

## Off-Chain Integrations
- **Chat gating:** Discord/Telegram bots (Collab.Land, Guild.xyz) verify `roleOf(address)` to grant or revoke server roles, keeping community discourse permissioned by token balance.【F:docs/docs/docs/docs/integrations.md†L1-L4】
- **Treasury transparency:** Event streams enable Dune dashboards or The Graph indexing for real-time tracking.
- **Proposal UX:** Snapshot or Tally can complement on-chain voting by surfacing proposal metadata and results.

## Security Considerations
- **Parameter governance:** Owners can adjust staking amount, voting delay/period, and quorum to react to participation patterns; front-ends must surface these updates clearly.【F:contracts/PeaceDAO.sol†L43-L72】
- **Stake refunds:** Ensures proposers are not financially punished for failed proposals, reducing griefing vectors and encouraging participation.【F:contracts/PeaceDAO.sol†L150-L169】
- **Blacklist safeguards:** Immediate mitigation for compromised wallets without touching treasury accounting.【F:contracts/PeaceGate.sol†L56-L63】
- **Future hardening:** Integrate multisig ownership transfer, expand event logging (`RoleGranted`, `RoleRevoked`), and consider snapshot-based tallying for gas efficiency.【F:README.md†L64-L86】

## Roadmap Highlights
1. **Snapshot-compatible voting:** Evaluate `ERC20Snapshot` integration for off-chain vote weighting.【F:README.md†L70-L83】
2. **Gnosis Safe timelock:** Route PeaceFund execution through a Safe + timelock module for defense-in-depth.【F:docs/docs/docs/docs/integrations.md†L1-L4】
3. **Expanded analytics:** Publish Dune dashboards covering donation inflows/outflows and role distribution.
4. **Localization & education:** Translate onboarding, security primers, and voter guides to serve multilingual communities.

## Glossary
- **PeaceGate:** Role-assignment contract gating chat/vote/propose rights via token balances.
- **PeaceDAO:** Proposal lifecycle contract enforcing staking, quorum, and refunding mechanics.
- **PeaceFund:** BNB-only treasury that executes disbursements on passed proposals.
- **StakeAmount:** Number of tokens proposers escrow until voting ends (default 1,000,000 units).
- **Quorum:** Minimum FOR-vote weight required for proposals to pass.

