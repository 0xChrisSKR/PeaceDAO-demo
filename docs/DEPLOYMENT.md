# Deployment Guide / 部署指南

This document consolidates all setup and deployment instructions for the PeaceDAO demo contracts. Follow the English and 中文 guidance side-by-side to prepare your environment, configure parameters, and deploy via Hardhat.

> ⚠️ Never commit or share `PRIVATE_KEY` to public repos. / 請勿將 `PRIVATE_KEY` 提交或分享至公開儲存庫。

## 1. Environment Setup / 環境設定

**English**

1. Install dependencies (`pnpm install` or `npm install`) if you have not already.
2. Copy the sample environment file and provide your RPC endpoint plus deployer key:
   ```bash
   cp .env.example .env
   ```
3. Edit `.env` with `RPC_URL` and `PRIVATE_KEY`. Optional overrides include `TOKEN_ADDRESS`, `FOUNDER_WALLET`, `UNDERLYING_ROUTER`, `SWAP_FEE_BPS`, `DAO_SHARE_BPS`, and `FOUNDER_SHARE_BPS`.

**中文**

1. 若尚未安裝依賴，請執行 `pnpm install` 或 `npm install`。
2. 複製環境變數範例檔並建立 `.env`：
   ```bash
   cp .env.example .env
   ```
3. 編輯 `.env`，輸入 `RPC_URL` 與 `PRIVATE_KEY`，亦可依需求覆寫 `TOKEN_ADDRESS`、`FOUNDER_WALLET`、`UNDERLYING_ROUTER`、`SWAP_FEE_BPS`、`DAO_SHARE_BPS`、`FOUNDER_SHARE_BPS` 等參數。

## 2. Deploy Configuration / 部署參數

**English**

- Review `deploy_config.json` for default governance thresholds, treasury floors, fee splits, and manager settings.
- Values in `.env` always override the JSON defaults during deployment.

**中文**

- 請檢視 `deploy_config.json` 了解預設的治理門檻、國庫最低值、手續費分配與管理員設定。
- 部署時若 `.env` 有提供對應參數，會優先生效並覆蓋 JSON 預設值。

## 3. Running Hardhat Scripts / 執行 Hardhat 指令

**English**

- Use the Hardhat runner to deploy the contracts:
  ```bash
  npx hardhat run --network bsctest scripts/deploy.ts
  ```
- The script deploys `PeaceFund`, `PeaceGate`, `PeaceDAO`, `PeaceSwapFeeCollector`, and `PeaceSwapRouter` in sequence.

**中文**

- 使用 Hardhat 指令部署合約：
  ```bash
  npx hardhat run --network bsctest scripts/deploy.ts
  ```
- 指令會依序部署 `PeaceFund`、`PeaceGate`、`PeaceDAO`、`PeaceSwapFeeCollector` 與 `PeaceSwapRouter`。

## 4. Networks / 網路設定

**English**

- `bsctest`: Binance Smart Chain Testnet (default in scripts).
- `bsc`: Binance Smart Chain Mainnet. Update `hardhat.config.ts` and `.env` accordingly before live deployment.

**中文**

- `bsctest`：幣安智能鏈測試網（指令預設使用）。
- `bsc`：幣安智能鏈主網。正式部署前請於 `hardhat.config.ts` 與 `.env` 調整對應參數。

## 5. Output & Verification / 部署結果與驗證

**English**

- After execution, the deploy script prints contract addresses for record keeping and front-end integration.
- Use the logged addresses to verify contracts on BscScan and configure PeaceDAO front-ends or tooling.

**中文**

- 部署完成後，指令會列出所有合約位址，請妥善備註並提供給前端或營運團隊使用。
- 可使用這些位址於 BscScan 進行合約驗證，並設定 PeaceDAO 前端或自動化工具。

## 6. Collaboration / 協作

**English**

- Fork the repository, propose security enhancements, or extend the governance toolkit via pull requests.

**中文**

- 歡迎 fork 此儲存庫、提出安全性改進建議，或透過 PR 擴充治理工具組。
