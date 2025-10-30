#!/usr/bin/env bash
set -euo pipefail

# Synchronise the latest Foundry deployment with the frontend repository.
#
# The script performs the following steps:
#   1. Compile contracts via `forge build` to ensure ABI artifacts exist.
#   2. Locate the newest `broadcast/**/<chainId>/run-*.json` deployment record.
#   3. Extract contract addresses for Donation, Treasury and Governance.
#   4. Emit `src/config/addresses.local.ts` in the frontend project.
#   5. Export ABIs as TypeScript modules under `src/abis/` for the same contracts.
#   6. Optionally run `npm run build` inside the frontend to ensure the
#      generated artifacts compile.

CHAIN_ID="${CHAIN_ID:-${TARGET_CHAIN_ID:-}}"
FRONTEND_DIR="${FRONTEND_DIR:-../PeaceDAO-frontend}"

# Allow overriding the contract list through CONTRACTS="Name1 Name2".
read -r -a CONTRACTS <<< "${CONTRACTS:-Donation Treasury Governance}"

command -v forge >/dev/null || { echo "❌ forge 未安裝（Foundry）"; exit 1; }
command -v jq >/dev/null    || { echo "❌ jq 未安裝"; exit 1; }

[ -d "$FRONTEND_DIR" ] || { echo "❌ 找不到前端目錄：$FRONTEND_DIR"; exit 1; }

echo "▶ 切換至 PeaceDAO-demo (contracts)" >&2
cd "$(dirname "$0")/.."

echo "🔨 forge build"
forge build >/dev/null

echo "🔎 尋找最新的部署紀錄"
if [ -n "$CHAIN_ID" ]; then
  RUN_FILE="$(ls -1t broadcast/*/"$CHAIN_ID"/run-*.json 2>/dev/null | head -n1 || true)"
else
  RUN_FILE="$(ls -1t broadcast/*/*/run-*.json 2>/dev/null | head -n1 || true)"
  if [ -n "$RUN_FILE" ]; then
    CHAIN_ID="$(echo "$RUN_FILE" | sed -E 's#.*/broadcast/.*/([0-9]+)/run-.*#\1#')"
  fi
fi

[ -n "${RUN_FILE:-}" ] || { echo "❌ 找不到 broadcast/*/<chainId>/run-*.json"; exit 1; }

echo "📄 使用部署記錄：$RUN_FILE (chainId=${CHAIN_ID:-?})"

# Prepare frontend directories.
mkdir -p "$FRONTEND_DIR/src/config" "$FRONTEND_DIR/src/abis"

# Collect addresses for configured contracts.
declare -A ADDRS=()
for NAME in "${CONTRACTS[@]}"; do
  ADDR="$(jq -r --arg n "$NAME" '.transactions[] | select(.contractName==$n) | .contractAddress' "$RUN_FILE" | tail -n1)"
  if [ -n "$ADDR" ] && [ "$ADDR" != "null" ]; then
    ADDRS["$NAME"]="$ADDR"
  else
    echo "⚠️  $NAME 未在部署紀錄中找到位址" >&2
    ADDRS["$NAME"]=""
  fi
done

ADDR_FILE="$FRONTEND_DIR/src/config/addresses.local.ts"
{
  echo "const ADDRESSES = {"
  echo "  ${CHAIN_ID:-0}: {"
  for NAME in "${CONTRACTS[@]}"; do
    UPPER="$(echo "$NAME" | tr '[:lower:]' '[:upper:]')"
    echo "    $UPPER: \"${ADDRS[$NAME]}\"," 
  done
  echo "  }"
  echo "} as const;"
  echo "export default ADDRESSES;"
} > "$ADDR_FILE"
echo "✅ 寫入 $(realpath --relative-to=. "$ADDR_FILE")"

# Export ABIs as TypeScript modules.
for NAME in "${CONTRACTS[@]}"; do
  ARTIFACT="$(ls -1 out/${NAME}.sol/${NAME}.json 2>/dev/null | head -n1 || true)"
  if [ -z "$ARTIFACT" ]; then
    echo "❌ 找不到 out/${NAME}.sol/${NAME}.json" >&2
    continue
  fi
  ABI="$(jq '.abi' "$ARTIFACT")"
  cat > "$FRONTEND_DIR/src/abis/${NAME}.ts" <<EOF
export const ${NAME}ABI = ${ABI} as const;
export default ${NAME}ABI;
EOF
  echo "✅ 生成 $(realpath --relative-to=. "$FRONTEND_DIR/src/abis/${NAME}.ts")"
done

echo "✅ 地址與 ABI 已匯出 → Frontend"

if [ "${SKIP_FRONTEND_BUILD:-0}" != "1" ]; then
  echo "▶ 檢查前端建置"
  (cd "$FRONTEND_DIR" && npm run build)
  echo "🎉 Frontend 已用真實位址與 ABI 編譯通過"
else
  echo "⚠️ 已跳過前端建置 (SKIP_FRONTEND_BUILD=1)"
fi
