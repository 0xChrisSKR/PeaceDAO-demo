> **For Binance engineers**  
> This repo demonstrates a **BNB-funded public treasury** governed by **$世界和平** token roles:  
> 100 = Speak, 200k = Vote, 1M = Propose (stake 1M, refunded after the vote).  
> All donation flows are **transparent on-chain** via `PeaceFund`.

 
# 🕊️ PeaceDAO Demo  
**Token-Verified DAO Chat & Governance Prototype**  

---
> This prototype responds to recent community scam incidents and suggests a token-verified governance pattern Binance engineers could explore.

### 💡 Vision
Decentralization without verification leads to chaos.  
PeaceDAO explores a **token-verified governance framework** that gives identity, accountability, and structure to decentralized communities.

> *"Peace needs protection — even on-chain."* ☮️

---

### Core Concept

A token-verified **public good DAO** where:
- **100 $世界和平** → speak in token-gated chat
- **200,000 $世界和平** → vote on proposals
- **1,000,000 $世界和平** → create proposals (requires staking 1,000,000; fully refunded after voting ends, regardless of result)

All **donations are in BNB** to a public on-chain treasury (PeaceFund).  
$世界和平 is strictly for **governance/identity** — not the donation currency.

---

### ⚙️ Smart Contract Overview

- `PeaceGate.sol` — role verification based on ERC-20 balance  
  - Thresholds (stored in smallest units): **100 / 200,000 / 1,000,000**
  - Blacklist & adjustable thresholds (owner)
  - `roleOf(address)` returns: NONE / SPEAKER / VOTER / PROPOSER

- `PeaceDAO.sol` — proposals & voting
  - **Propose**: PROPOSER must stake **1,000,000 $世界和平** (refunded after voting ends)
  - **Vote**: VOTER role (≥ 200,000)
  - **Quorum** configurable; on **pass**, DAO instructs treasury to send **BNB**
  - **No slashing**: stake is **always refunded**, pass or fail

- `PeaceFund.sol` — BNB-only treasury
  - Receives donations in BNB (`receive()` / `donate()`)
  - Executes `transferNative(to, amount, proposalId)` **only when DAO says so**
  - `balance()` & events for full transparency (Dune/TheGraph ready)

---

### Current Features

- ✅ On-chain role checking (`roleOf`) with **100/200k/1M** thresholds
- ✅ Proposal creation with **1M stake** (auto-refund after vote ends)
- ✅ BNB-only public treasury with on-chain logs
- ✅ Adjustable params: thresholds, quorum, voting delay/period
- ✅ Event logs for bot integrations (Discord/Guild token-gating)
- ⚙️ Front-end is EIP-1193 **injected wallet–ready** (Binance Web3 Wallet, OKX, MetaMask…)


---

### 🔐 Security & Next Steps
This repository is a **concept demo — not for mainnet deployment**.  
Future improvements include:
1. Snapshot-based voting integration (using `ERC20Snapshot` or Governor).  
2. Role verification via multisig / timelock for additional security.  
3. Expand event logging for audit trails (`RoleGranted`, `Blacklisted`, etc.).  
4. Integrate with a treasury contract (`Gnosis Safe + Timelock`).  
5. Re-entrancy and overflow protection with OpenZeppelin libraries.  

---

### 🤖 Token-Gated Chat Integration
**Goal:** connect contract logic to real community platforms.

Suggested tools:
- Discord / Telegram → [Collab.Land](https://collab.land/) or [Guild.xyz](https://guild.xyz/)  
- Web gating → [Unlock Protocol](https://unlock-protocol.com/)  
- Voting UI → [Snapshot](https://snapshot.org/) / [Tally](https://tally.xyz/)  
- Treasury execution → [Gnosis Safe](https://gnosis-safe.io/)  

**Bot verification logic (simplified):**
1. User clicks *Verify* → bot requests wallet signature (no private key).  
2. Bot checks `roleOf(address)` via RPC.  
3. Grants appropriate chat role (reader / voter / proposer).  
4. Periodically revalidates or on-demand before voting.

---

### 🧠 Why This Matters
Scams in open Telegram communities show how fragile trust can be.  
By introducing **on-chain verified access**, communities can stay open yet secure.  
It’s not about centralization — it’s about *verified decentralization*.

---

### 🧰 For Developers
If you’re a Solidity or Web3 engineer, feel free to:
- Fork this repo  
- Suggest security enhancements  
- Prototype a front-end demo (token-gated chat)  
- Submit pull requests or issues  

---

### 🧑‍💻 Author
Created by **[@0xChris.SKR](https://twitter.com/0xChris_SKR)**  
Project: **[$世界和平](https://twitter.com/search?q=%24世界和平&src=typed_query)**  
No team, no funding — just an idea for a safer decentralized future.  

---

### 🪪 License
MIT License — free to fork, build, and improve.  
Use at your own risk. Not audited.

---
**DISCLAIMER:** Conceptual prototype. Not audited. Not financial advice. Do NOT deploy to mainnet.
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
