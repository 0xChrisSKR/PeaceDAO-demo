#!/usr/bin/env bash
set -euo pipefail

# === 你可以只改這兩個變數 ===
TARGET_CHAIN_ID="${TARGET_CHAIN_ID:-}"     # 不填就自動偵測
FRONTEND_DIR="${FRONTEND_DIR:-../PeaceDAO-frontend}"

# --- 檢查工具 ---
command -v forge >/dev/null || { echo "❌ 未安裝 foundry（forge/cast）。先執行：curl -L https://foundry.paradigm.xyz | bash && foundryup"; exit 1; }
command -v jq >/dev/null    || { echo "❌ 未安裝 jq。請安裝 jq 後再試"; exit 1; }

# --- 編譯，產生 out/* 工件 ---
echo "🔨 forge build"
forge build >/dev/null

# --- 找最新的 run-latest.json ---
if [ -n "${TARGET_CHAIN_ID}" ]; then
  RUN_FILE="$(ls -t broadcast/*/${TARGET_CHAIN_ID}/run-latest.json 2>/dev/null | head -n 1 || true)"
else
  RUN_FILE="$(ls -t broadcast/*/*/run-latest.json 2>/dev/null | head -n 1 || true)"
  TARGET_CHAIN_ID="$(echo "$RUN_FILE" | sed -E 's#.*/broadcast/.*/([0-9]+)/run-latest.json#\1#')"
fi
[ -n "${RUN_FILE}" ] || { echo "❌ 找不到 broadcast/*/*/run-latest.json，請先成功部署一次（forge script ... --broadcast）"; exit 1; }

echo "📄 使用部署記錄：$RUN_FILE (chainId=$TARGET_CHAIN_ID)"

# --- 取出本次建立( CREATE / CREATE2 )的合約名與位址 ---
mapfile -t NAMES < <(jq -r '.transactions[] | select(.transactionType|startswith("CREATE")) | .contractName' "$RUN_FILE" | sort -u)
[ ${#NAMES[@]} -gt 0 ] || { echo "❌ 此次部署沒有 CREATE 交易，檢查你的部署腳本"; exit 1; }

mkdir -p "$FRONTEND_DIR/src/config" "$FRONTEND_DIR/src/abis"

ADDR_FILE="$FRONTEND_DIR/src/config/addresses.local.json"
jq -n '{}' > "$ADDR_FILE"

echo "🔎 匯出位址與 ABI ..."
for NAME in "${NAMES[@]}"; do
  ADDR="$(jq -r --arg n "$NAME" '.transactions[] | select(.transactionType|startswith("CREATE")) | select(.contractName==$n) | .contractAddress' "$RUN_FILE" | tail -n1)"
  [ -n "$ADDR" ] || continue

  # 寫入 addresses.local.json
  tmp="$(mktemp)"; jq --arg k "$NAME" --arg v "$ADDR" '.[$k]=$v' "$ADDR_FILE" > "$tmp" && mv "$tmp" "$ADDR_FILE"

  # 找對應 artifact（out/**/$NAME.json）
  ART="$(find out -type f -name "$NAME.json" | head -n 1 || true)"
  if [ -z "$ART" ]; then
    # 用 forge inspect 當後備
    forge inspect "$NAME" abi > "$FRONTEND_DIR/src/abis/$NAME.abi.json" 2>/dev/null || {
      echo "⚠️  找不到 $NAME 的 artifact；請確認合約名與 out/ 內容"; continue; }
  else
    jq '.abi' "$ART" > "$FRONTEND_DIR/src/abis/$NAME.abi.json"
  fi

  # 產生對應 TS 匯出
  {
    printf 'export const %sABI = ' "$NAME"
    cat "$FRONTEND_DIR/src/abis/$NAME.abi.json"
    echo ' as const;'
  } > "$FRONTEND_DIR/src/abis/$NAME.ts"

  echo "  • $NAME  =>  $ADDR"
done

# --- 產生簡單 contracts.ts（優先用環境變數，否則 fallback 本地檔）---
cat > "$FRONTEND_DIR/src/config/contracts.ts" <<'TS'
import local from "./addresses.local.json";
export const CONTRACTS = {
  DONATION_ADDRESS: process.env.NEXT_PUBLIC_DONATION_ADDRESS || local.Donation || local.Donations || "",
  TREASURY_ADDRESS: process.env.NEXT_PUBLIC_TREASURY_ADDRESS || local.Treasury || "",
  GOVERNANCE_ADDRESS: process.env.NEXT_PUBLIC_GOVERNANCE_ADDRESS || local.Governance || local.Governor || "",
};
TS

# --- 列出可貼到 Vercel 的建議環境變數 ---
echo " "
echo "🧭 建議設定到 Vercel 的 NEXT_PUBLIC_*："
DON=$(jq -r '.Donation // .Donations // empty' "$ADDR_FILE")
TRE=$(jq -r '.Treasury // empty' "$ADDR_FILE")
GOV=$(jq -r '.Governance // .Governor // empty' "$ADDR_FILE")
printf "  NEXT_PUBLIC_CHAIN_ID=%s\n" "${TARGET_CHAIN_ID:-<your_chain_id>}"
[ -n "$DON" ] && echo "  NEXT_PUBLIC_DONATION_ADDRESS=$DON"
[ -n "$TRE" ] && echo "  NEXT_PUBLIC_TREASURY_ADDRESS=$TRE"
[ -n "$GOV" ] && echo "  NEXT_PUBLIC_GOVERNANCE_ADDRESS=$GOV"
echo "  （RPC 可填：NEXT_PUBLIC_RPC_HTTP=<你的 RPC URL>）"

# --- 建分支並推到前端 repo ---
echo " "
echo "📦 提交到前端 repo..."
cd "$FRONTEND_DIR"
git fetch origin
git checkout -B codex/import-addresses-abis
git add src/abis src/config/addresses.local.json src/config/contracts.ts
git commit -m "chore: import deployed addresses & ABIs from Foundry; add contracts mapping" || true
git push -u origin codex/import-addresses-abis

echo "✅ 完成：位址與 ABI 已匯入前端並建立分支 'codex/import-addresses-abis'"
