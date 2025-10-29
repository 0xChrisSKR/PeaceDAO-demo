#!/usr/bin/env bash
set -euo pipefail

# This script mirrors the manual verification steps for the PeaceDAO demo and frontend projects.
# It clones (or updates) both repositories, installs dependencies, compiles/contracts where possible,
# and reports on the presence of artifacts, ABIs, and environment configuration files.

DEMO_REPO="https://github.com/0xChrisSKR/PeaceDAO-demo.git"
FRONT_REPO="https://github.com/0xChrisSKR/PeaceDAO-frontend.git"
WORKDIR="${WORKDIR:-$HOME/peacedao_check}"  # Allow overriding via environment variable.

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Preparing/updating repositories"
if [ ! -d PeaceDAO-demo ]; then
  git clone --depth=1 "$DEMO_REPO"
else
  (cd PeaceDAO-demo && git pull --ff-only || true)
fi

if [ ! -d PeaceDAO-frontend ]; then
  git clone --depth=1 "$FRONT_REPO"
else
  (cd PeaceDAO-frontend && git pull --ff-only || true)
fi

printf '\n================ PeaceDAO-demo (contracts) ================\n'
cd "$WORKDIR/PeaceDAO-demo"

if [ -d contracts ]; then
  echo "✔ contracts/ found:" && ls -1 contracts | sed 's/^/   - /'
else
  echo "✘ No contracts/ directory"
fi

if [ -f package.json ]; then
  echo "==> Installing/verifying npm dependencies"
  npm ci --silent || npm i --silent
fi

if [ -f hardhat.config.ts ] || [ -f hardhat.config.js ]; then
  echo "==> Running hardhat compile"
  npx hardhat compile || true
fi

if command -v forge >/dev/null 2>&1 || [ -f foundry.toml ]; then
  echo "==> Running forge build"
  forge build || true
fi

echo "==> Checking artifacts"
if [ -d artifacts ]; then
  echo -n "  JSON artifacts count: "
  find artifacts -name "*.json" | wc -l
  find artifacts -maxdepth 2 -name "*.json" | head -n 10 | sed 's/^/   - /'
else
  echo "  No artifacts/ directory found"
fi

echo "==> Looking for deployment addresses"
FOUND_ADDR=0
if [ -d deployments ]; then
  echo "  Found in deployments/"
  grep -R --line-number -E '"address"|"contractAddress"' deployments || true
  FOUND_ADDR=1
fi
if [ -d broadcast ]; then
  echo "  Found in broadcast/"
  grep -R --line-number -E '"address"|"contractAddress"' broadcast || true
  FOUND_ADDR=1
fi
if [ $FOUND_ADDR -eq 0 ]; then
  echo "  No deployment address records detected"
fi

printf '\n================ PeaceDAO-frontend (frontend) ================\n'
cd "$WORKDIR/PeaceDAO-frontend"

ABI_OK=1
for f in "src/abi/DonationToken.json" "src/abi/Governor.json"; do
  if [ -f "$f" ]; then
    echo "✔ Found $f"
  else
    echo "✘ Missing $f"
    ABI_OK=0
  fi
done

if ls -1a .env* 2>/dev/null | grep -qE '^\.env'; then
  echo "✔ Found environment files:" && ls -1a .env*
  echo "   Checking key NEXT_PUBLIC_ variables:"
  grep -nE 'NEXT_PUBLIC_(CHAIN_ID|RPC_URL|WC_ID|DONATION_TOKEN_ADDR|GOVERNOR_ADDR)' .env* || echo "   ✘ Missing key NEXT_PUBLIC_ variables"
else
  echo "✘ No .env files detected"
fi

if [ -f i18n.ts ]; then
  echo "✔ i18n.ts present"
  grep -nE 'i18n:\s*\{|defaultLocale|locales|localeDetection|fallbackLng' i18n.ts || true
else
  echo "✘ Missing i18n.ts"
fi

CFG=""
if [ -f next.config.mjs ]; then
  CFG="next.config.mjs"
elif [ -f next.config.js ]; then
  CFG="next.config.js"
fi

if [ -n "$CFG" ]; then
  echo "✔ Found $CFG"
  echo "   webpack aliases and i18n excerpt:"
  grep -nE 'i18n|webpack|alias|pino-pretty|async-storage' "$CFG" || true
else
  echo "✘ Missing Next.js config"
fi

if [ -f package.json ]; then
  echo "==> Installing/verifying frontend dependencies"
  npm ci --silent || npm i --silent
  echo "==> Attempting frontend build"
  npm run build || true
else
  echo "✘ Frontend package.json missing"
fi

printf '\n================ Summary ================\n'
echo "• Demo contracts: check artifacts/deployments output above to verify compilation or deployment status."
echo "• Frontend: ensure ABIs and environment variables exist; if build failed, prioritise fixing i18n/wallet dependencies."
