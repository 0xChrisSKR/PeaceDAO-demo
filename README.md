# 🕊️ PeaceDAO Demo
**Token-Verified DAO Chat & Governance Prototype**

World Peace DAO explores a token-verified governance framework that brings accountability and structure to decentralized communities.

> *"Peace needs protection — even on-chain."* ☮️

## Vision

Decentralization without verification leads to chaos. PeaceDAO proposes a balanced model where $世界和平 token thresholds safeguard participation while preserving openness and transparency for public-good funding.

## Governance Highlights

- **Governance thresholds** ensure only committed holders can propose (1,000,000 $世界和平), vote (200,000 $世界和平), or speak (100 $世界和平).
- **Anti-Sybil guardrails** add cooldowns between proposals and enhanced review for high-value requests.
- **Transparent donations** route all BNB contributions through the PeaceFund, with verifiers and community managers sharing operational rewards.

詳見雙語版 [World Peace DAO — Whitepaper v2](docs/whitepaper.md)。

For setup and deployment, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Testnet Deploy (Quick)

1. `cp .env.example .env`
2. Fill in `RPC_URL` and `PRIVATE_KEY` (use a testnet wallet only, never commit private keys).
3. `npm ci`
4. `npx hardhat compile`
5. `npx hardhat run --network bsctest scripts/deploy_peacefund.ts`
6. _(Optional)_ `npx hardhat run --network bsctest scripts/deploy_router.ts`

Example output:

```
{ "network":"bsctest", "PeaceFund":"0x...." }
{ "network":"bsctest", "PeaceSwapRouter":"0x...." }
```

## CI Deploy

- Add the `RPC_URL` and `PRIVATE_KEY` repository secrets in GitHub.
- Trigger **Actions → Deploy PeaceFund (BSC Testnet) → Run workflow** when you need a fresh PeaceFund address.
- The workflow will compile, deploy, and automatically write the new address back into the docs and `deployments/bsctest.json`.

## Treasury / Addresses

- BSC Mainnet PeaceFund: 0x6bfA2878fdC394D771349E29d423244d2Ec82af1
- BSC Testnet PeaceFund: {{PEACEFUND_BSCTEST}}

## Mainnet deploy (BSC)

1. Set the repository secrets `RPC_URL_MAINNET` and `PRIVATE_KEY`.
2. Run **Actions → Deploy PeaceFund (BSC Mainnet)** to trigger the one-click deployment.
3. After deployment, the workflow records the address in `deployments/bsc.json` and replaces `0x6bfA2878fdC394D771349E29d423244d2Ec82af1` in this README and `docs/WHITEPAPER.md`.

## Bridge to Frontend

- Copy addresses into `PeaceDAO-frontend/.env.local`:
  - `NEXT_PUBLIC_PEACE_FUND=<PeaceFund>`
  - `NEXT_PUBLIC_PEACE_SWAP_ROUTER=<PeaceSwapRouter or Pancake test router>`
- Restart the frontend: `npm run dev`

### Safety Notes

- Never use a mainnet private key for testing; fund a dedicated testnet wallet only.
- When preparing for mainnet, verify the deployed contracts on BscScan for transparency.

## Frontend UI

- **Framework:** Next.js app directory structure (see the `app/` folder) with styling that mirrors Tailwind's default system font stack.
- **Offline-friendly typography:** Tailwind's default `font-sans` stack is applied locally so no Google Fonts are fetched during CI/CD builds.
- **Build command:** `npm run build` compiles the smart contracts; no extra network calls are made for fonts, keeping the pipeline offline-friendly.

## Repositories & Documentation

- [Smart Contracts (this repo)](https://github.com/peacebuild/PeaceDAO-demo)
- [Whitepaper](docs/whitepaper.md)
- [PeaceDAO Governance Toolkit](https://github.com/peacebuild)

## Community / 社群

- Telegram: [Public Discussion Group 公開討論群](https://t.me/WorldPeace_BNB)
- Telegram: [Verified DAO Group 驗證群組](https://t.me/+i-dpunM-luk1ZjRl)

> ✅ Verified DAO members will automatically receive the **Peace Ambassador** role and may qualify for future **NFT badges** recognizing verified contributions.  
> 經驗證的 DAO 成員將自動獲得 **和平大使 (Peace Ambassador)** 身分，並可獲得未來 DAO 發行的 **貢獻 NFT 勳章**。

- Twitter: [@0xChris_SKR](https://twitter.com/0xChris_SKR) & [$世界和平](https://twitter.com/search?q=%24世界和平&src=typed_query)
- GitHub: [peacebuild](https://github.com/peacebuild)

## License

MIT License — use at your own risk. Not audited. Not financial advice.

**DISCLAIMER:** Conceptual prototype. Do NOT deploy to mainnet.
