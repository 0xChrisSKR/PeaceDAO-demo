# Architecture
Token → Role (PeaceGate) → Chat/Vote (off-chain UIs) → Execute (Timelock/Safe)

- PeaceGate: manages thresholds, blacklist, and emits events for bots.
- PeaceDAO: proposal lifecycle (create → vote → execute) with quorum logic.
- Integrations: Guild/Collab.Land for chat gating, Snapshot/Tally for voting, Gnosis Safe for treasury execution.

## PeaceSwap 模組 / PeaceSwap Module

- PeaceSwapRouter：前端面向的 swap 入口，負責扣除 0.5% 手續費並呼叫底層 DEX Router。
- PeaceSwapFeeCollector：收到 router 授權的費用，80% 匯入 DAO 國庫、20% 匯入創辦人營運地址；支援原生幣與 ERC-20。
- 底層 DEX：保持既有的流動性與最佳路徑，只需提供 `swapExactTokensForTokens` 介面即可。

Fee flow / 費用流程：

1. 使用者將 ERC-20 授權給 PeaceSwapRouter 並送出 swap 請求。
2. Router 扣除 0.5% 並授權 FeeCollector 拉走費用。
3. FeeCollector 立即按 80%：20% 匯款至 DAO / Founder。
4. Router 將 99.5% 淨額交給底層 DEX Router，使用者收到最終輸出資產。

Example：swap 1,000 代幣 → 5 fee → 4 給 DAO、1 給 Founder，995 進入 DEX。
