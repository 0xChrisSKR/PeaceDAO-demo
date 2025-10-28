# World Peace DAO — Whitepaper v2 （雙語）

> “Peace needs protection — even on-chain.”  
> 「和平需要被保護，鏈上也一樣。」

## 1. Overview / 總覽
World Peace DAO（$世界和平）是一個建立在 BNB Chain 的去中心化公益治理模型：  
所有捐贈與治理行為在鏈上透明記錄；經濟激勵來自「合理的營運金」與「交易手續費」，確保公益可持續而非只靠口號。

- 主治理代幣（治理用、非捐贈貨幣）：`0x4444def5cf226bf50aa4b45e5748b676945bc509`
- Founder 營運收款錢包（Operations）：`0xD05d14e33D34F18731F7658eCA2675E9490A32D3`

## 2. Roles & Thresholds / 角色與門檻
- **Proposer 提案者**：需質押 **1,000,000 $世界和平**，投票結束後退還；另有 **+7 天鎖定**。
- **Voter 投票者**：需質押 **200,000 $世界和平**，投票結束後退還。
- **Voting Period 投票時長**：固定 **24 小時**。
- **Anti-Sybil**：  
  - **30 天冷卻期**：同一地址提案間隔 ≥ 30 天；  
  - **90 天視窗限額**：每地址 90 天內最多 1 次提案；  
  - **> US$5,000 守門**：當預計捐贈金額超過 5,000 美元，需 Verified Proposer（SBT/白名單）或多簽核可。

## 3. Donation & Treasury / 捐贈與金庫
所有捐贈以 **BNB** 進入 **PeaceFund（原生幣金庫）**。  
執行通過之提案時：  
- **90%** → 直接匯給受贈者（Beneficiary）  
- **10%** → 作為營運金（Ops）

> 為了安全與會計清晰：  
> - **原生幣（BNB）** → PeaceFund（native-only）  
> - **ERC-20 手續費** → DaoVaultERC20（ERC-20 金庫）

## 4. Incentives / 激勵
- **Verifier（捐贈驗證者）獎勵**：每次成功驗證，獲 **0.005%**（50ppm）**由 10% 營運金中支出**。  
- **Community Managers（含 TG Admin）社群管理員獎勵**：  
  - 資格：需持幣 **≥ 500,000**，且在任期內**質押**  
  - 任命/罷免：**DAO 提案**產生；同時最多 `maxManagers`（預設 3 位）  
  - 每次捐贈，管理員共享 **0.005%**（50ppm），同樣**由 10% 營運金中支出**（與 Verifier 不衝突、受贈 90% 不變）

> 營運金的剩餘部分撥給 Founder Operations（用於維運、審計、基礎設施）。

## 5. PeaceSwap Module / 交換模組
為了「自我造血」，我們引入 **PeaceSwap Router**（不自建 DEX，包一層 Router）：  
- **手續費：0.5%**（`feeBps=50`）  
- **分潤**：**80% → DAO**、**20% → Founder**  
- **費用去向**：  
  - 原生手續費 → **PeaceFund**（DAO） & Founder  
  - ERC-20 手續費 → **DaoVaultERC20**（DAO） & Founder  
- 事件：`SwapWithFee(...)` 完整記錄來源、幣對、毛額、手續費、實得

## 6. Telegram Governance / Telegram 治理
我們**不做站內聊天室 dApp**，而是採用 **Telegram + token-gating**：  
- **Public Group**：開放溝通  
- **World Peace DAO Group**：持幣驗證（建議門檻 100），使用 **Collab.Land / Guild.xyz**  
- 重要投票與提案仍以鏈上合約為準，TG 僅作為社群協調工具

## 7. Security Model / 安全模型
- **合約層**：`ReentrancyGuard`、`SafeERC20`、`Pausable`、參數上限、CEI 流程  
- **國庫層**：`AccessControl` 角色、**Timelock（≥24h）**、多簽（Gnosis Safe）、每日/單筆上限  
- **資產隔離**：BNB → PeaceFund、ERC-20 → DaoVaultERC20；PeaceFund 提供 `sweepERC20()`（僅財務角色）  
- **監控**：事件標準化（Dune/Defender/Forta 監控）、重要操作告警  
- **流程**：測網 → 內部/第三方審計 → Bounty → 小額上線 → 放量

## 8. Parameters & Addresses / 參數與地址
| Item | Value |
|---|---|
| Founder Ops Wallet | `0xD05d14e33D34F18731F7658eCA2675E9490A32D3` |
| Governance Token ($世界和平) | `0x4444def5cf226bf50aa4b45e5748b676945bc509` |
| Propose Stake | 1,000,000 |
| Vote Stake | 200,000 |
| Voting Period | 24h |
| Proposer Extra Lock | 7d |
| DAO Managers Min Stake | 500,000 |
| Manager Cap | 3 |
| Verifier Reward | 0.005% of donation (from ops) |
| Managers Reward | 0.005% of donation (from ops, equally shared) |
| Ops Split | PeaceSwap fee 80% DAO / 20% Founder |
| PeaceSwap Fee | 0.5% |

## 9. Roadmap / 路線圖
1) Testnet 合約與前端 Demo  
2) 安全加固（Timelock、多簽、限額、監控）  
3) 白名單公益機構名錄 + 高額提案保護  
4) Dune Dashboard 與定期透明報告  
5) Mainnet 小規模運行 → 放量

## 10. Disclaimer / 免責
本文件為開源研究與原型說明，不構成投資建議。任何主網部署前皆需完整審計與安全驗證。
