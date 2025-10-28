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

World Peace DAO v2 focuses on sustainable, transparent public-good funding. Key mechanics:
- **Governance thresholds**: **1,000,000 $世界和平** to propose (stake refunded +7 天鎖定), **200,000 $世界和平** to vote, and **stake refunds** return at vote end.
- **Anti-Sybil guardrails**: 30 天冷卻期 between proposals per address, 90 天視窗最多 1 次提案，and proposals exceeding **US$5,000** require a verified proposer or multisig hook approval.
- **Donation routing**: All BNB donations flow to **PeaceFund**. Each executed proposal sends **90%** directly to the beneficiary and **10%** to operations for verifiers、community managers、以及 Founder 維運。
- **Incentive splits** (from the 10% ops budget): verifiers earn **0.005%** per validated donation; community managers（含 Telegram admins，需 ≥500,000 並質押）共享 **0.005%**；beneficiary share 永遠維持 90%。
- **PeaceSwap fees**: Router charges **0.5%** (`feeBps=50`)，其中 **80%** 回饋 DAO、**20%** 分潤 Founder；原生幣費用進 PeaceFund，ERC-20 手續費進 DaoVaultERC20。

詳見雙語版 [World Peace DAO — Whitepaper v2](docs/whitepaper.md)。

> TODO: add fee flow diagram (`docs/diagrams/fee-flow.png`) when finalized.

---

### ⚙️ Smart Contract Overview

- `PeaceGate.sol`
  - Maintains governance thresholds for speaking (100)、voting (**200,000**)、proposing (**1,000,000** +7d lock)。
  - Token balance checks power Telegram gating via Collab.Land / Guild.

- `PeaceDAO.sol`
  - Proposal stake refunds after the **24h** voting period; proposer stake remains locked an extra 7 天。
  - Enforces 30d cooldown + 90d rolling cap per proposer and integrates high-value (>US$5k) guards for verified submitters or multisig review。
  - On approval, triggers PeaceFund / DaoVaultERC20 payouts with baked-in splits for beneficiary 90%、ops 10%。

- `PeaceFund.sol` & `DaoVaultERC20.sol`
  - PeaceFund holds native BNB; DaoVaultERC20 holds ERC-20 fees/donations。
  - Operations distribution automates **0.005%** to verifiers and **0.005%** to community managers from the ops share while forwarding the remainder to the Founder operations wallet `0xD05d14e33D34F18731F7658eCA2675E9490A32D3`。

- `PeaceSwapRouter.sol`
  - Wraps existing DEX liquidity with a **0.5%** fee; routes **80%** of fees to DAO treasuries (native → PeaceFund, ERC-20 → DaoVaultERC20) and **20%** to Founder.

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
World Peace DAO v2 強化鏈上與 off-chain 安全流程：
1. 合約層：採用 `ReentrancyGuard`、`SafeERC20`、`Pausable`，搭配參數上限與 Checks-Effects-Interactions 流程。
2. 國庫層：`AccessControl` 角色管理、**Timelock ≥24h**、Gnosis Safe 多簽、每日/單筆限額。
3. Anti-Sybil：提案間隔 30 天、90 天視窗最多 1 件、超過 **US$5,000** 需 verified proposer 或多簽掛鉤。
4. 監控：標準化事件（利於 Dune/Defender/Forta）及重要操作警示。
5. 發布流程：測網 → 內/外部審計 → Bounty → 小額上線 → 放量。

---

### 🤖 Token-Gated Chat Integration
站內不再提供聊天 dApp；社群協作以 **Telegram** 為核心：
- **Public Group**：開放討論。
- **Token-Gated Group**：透過 [Collab.Land](https://collab.land/) 或 [Guild.xyz](https://guild.xyz/) 以 $世界和平 餘額驗證（建議門檻 100）。
- **管理獎勵**：通過 DAO 提案任命的 community managers / TG admins，在每筆捐贈中由 ops share 分潤 **0.005%**。
- **投票與執行**：最終以鏈上 PeaceDAO 合約為準，Telegram 主要提供提醒、協調與守門機制。

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

### 🚀 Deployment Setup / 部署設定

**English**

1. Copy the sample env file and fill in your RPC + private key:
   ```bash
   cp .env.example .env
   ```
2. Edit `.env` to provide `RPC_URL` and `PRIVATE_KEY`. You can also override addresses or fee splits (`TOKEN_ADDRESS`, `FOUNDER_WALLET`, `UNDERLYING_ROUTER`, `SWAP_FEE_BPS`, `DAO_SHARE_BPS`, `FOUNDER_SHARE_BPS`).
3. Review `deploy_config.json` for default parameters (vote/proposal stakes, treasury floor, fee basis points, manager settings). Environment variables always override the JSON defaults at runtime.
4. Run the Hardhat deploy script:
   ```bash
   npx hardhat run --network bsctest scripts/deploy.ts
   ```
5. The script deploys `PeaceFund`, `PeaceGate`, `PeaceDAO`, `PeaceSwapFeeCollector`, and `PeaceSwapRouter`, then prints every address so you can record them or plug into front-end tooling.

**中文**

1. 先複製範例環境檔並填入 RPC 與私鑰：
   ```bash
   cp .env.example .env
   ```
2. 編輯 `.env`，輸入 `RPC_URL` 與 `PRIVATE_KEY`，也可以依需求覆寫位址或分潤參數（如 `TOKEN_ADDRESS`、`FOUNDER_WALLET`、`UNDERLYING_ROUTER`、`SWAP_FEE_BPS`、`DAO_SHARE_BPS`、`FOUNDER_SHARE_BPS`）。
3. 檢視 `deploy_config.json` 了解預設參數（投票/提案質押門檻、金庫最低美元值、手續費分配、管理員設定）；部署時若 `.env` 有設定，會優先生效。
4. 執行 Hardhat 部署指令：
   ```bash
   npx hardhat run --network bsctest scripts/deploy.ts
   ```
5. 指令會部署 `PeaceFund`、`PeaceGate`、`PeaceDAO`、`PeaceSwapFeeCollector`、`PeaceSwapRouter`，並逐一列出合約位址，方便備註或提供前端使用。

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
