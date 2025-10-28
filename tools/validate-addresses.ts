#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
let dotenv;
try {
  dotenv = require("dotenv");
} catch (err) {
  console.warn("[validate-addresses] dotenv not installed; skipping .env loading");
}

const ROOT = path.join(__dirname, "..");
const CONFIG_PATH = path.join(ROOT, "deploy_config.json");
const ENV_PATH = path.join(ROOT, ".env");

let deployConfig = {};
if (fs.existsSync(CONFIG_PATH)) {
  try {
    deployConfig = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch (err) {
    console.error(`Failed to parse deploy_config.json: ${err}`);
  }
}

if (dotenv) {
  if (fs.existsSync(ENV_PATH)) {
    dotenv.config({ path: ENV_PATH });
  } else {
    dotenv.config();
  }
}

const normalize = (addr) => (addr ? addr.toLowerCase() : "");
const founderEnv = process.env.FOUNDER_WALLET || "";
const tokenEnv = process.env.TOKEN_ADDRESS || "";
const founderConfig = deployConfig.founderWallet || "";
const tokenConfig = deployConfig.tokenAddress || "";

const expectedFounder = normalize(founderEnv || founderConfig);
const expectedToken = normalize(tokenEnv || tokenConfig);

const founderKeywords = ["founder", "創辦", "founder_wallet", "founder wallet"];
const tokenKeywords = ["token", "世界和平", "governance token", "token_address", "$世界和平"];
const docRoots = ["README.md", "docs"];
const scanRoots = ["contracts", "scripts", "docs", "README.md", "deploy_config.json", "hardhat.config.ts", ".env.example"];

const founderMatches = new Map();
const tokenMatches = new Map();
const docMatches = new Map();

const addressRegex = /0x[a-fA-F0-9]{40}/g;
const skipDirs = new Set([".git", "node_modules", "artifacts", "cache", "out", "dist", "coverage"]);

function track(map, address, location) {
  const key = normalize(address);
  if (!map.has(key)) {
    map.set(key, new Set());
  }
  map.get(key).add(location);
}

function isDocFile(relativePath) {
  return docRoots.some((root) => relativePath === root || relativePath.startsWith(`${root}/`));
}

function walk(currentPath) {
  const stats = fs.statSync(currentPath);
  if (stats.isDirectory()) {
    const base = path.basename(currentPath);
    if (skipDirs.has(base)) {
      return;
    }
    const entries = fs.readdirSync(currentPath);
    for (const entry of entries) {
      walk(path.join(currentPath, entry));
    }
    return;
  }

  const relPath = path.relative(ROOT, currentPath).replace(/\\/g, "/");
  const content = fs.readFileSync(currentPath, "utf8");
  const lines = content.split(/\r?\n/);
  lines.forEach((line, index) => {
    if (!line) return;
    const lower = line.toLowerCase();
    const matches = line.match(addressRegex);
    if (!matches) {
      return;
    }
    const location = `${relPath}:${index + 1}`;
    const hasFounderKeyword = founderKeywords.some((kw) => lower.includes(kw));
    const hasTokenKeyword = tokenKeywords.some((kw) => lower.includes(kw));
    matches.forEach((addr) => {
      if (hasFounderKeyword) {
        track(founderMatches, addr, location);
      }
      if (hasTokenKeyword) {
        track(tokenMatches, addr, location);
      }
      if (isDocFile(relPath)) {
        track(docMatches, addr, location);
      }
    });
  });
}

scanRoots.forEach((rootItem) => {
  const absolute = path.join(ROOT, rootItem);
  if (fs.existsSync(absolute)) {
    walk(absolute);
  }
});

function formatMap(map) {
  if (map.size === 0) {
    return "not referenced";
  }
  return Array.from(map.entries())
    .map(([addr, locations]) => `${addr} (${Array.from(locations).join(", ")})`)
    .join("; ");
}

const issues = [];
const summary = [];

const founderStatus = (() => {
  if (!expectedFounder) {
    issues.push("Founder wallet missing from environment or deploy_config.json");
    return "missing";
  }
  if (founderMatches.size === 0) {
    return "not referenced";
  }
  const mismatches = Array.from(founderMatches.keys()).filter((addr) => addr && addr !== expectedFounder);
  if (founderEnv && founderConfig && normalize(founderEnv) !== normalize(founderConfig)) {
    issues.push("Founder wallet differs between .env and deploy_config.json");
  }
  if (mismatches.length > 0) {
    issues.push(`Found founder wallet mismatches: ${mismatches.join(", ")}`);
    return "mismatch";
  }
  return "ok";
})();

const tokenStatus = (() => {
  if (!expectedToken) {
    issues.push("Token address missing from environment or deploy_config.json");
    return "missing";
  }
  if (tokenMatches.size === 0) {
    return "not referenced";
  }
  const mismatches = Array.from(tokenMatches.keys()).filter((addr) => addr && addr !== expectedToken);
  if (tokenEnv && tokenConfig && normalize(tokenEnv) !== normalize(tokenConfig)) {
    issues.push("Token address differs between .env and deploy_config.json");
  }
  if (mismatches.length > 0) {
    issues.push(`Found token address mismatches: ${mismatches.join(", ")}`);
    return "mismatch";
  }
  return "ok";
})();

const docMismatches = Array.from(docMatches.keys()).filter(
  (addr) => addr && addr !== expectedFounder && addr !== expectedToken
);
if (docMismatches.length > 0) {
  issues.push(`Documentation references mismatched addresses: ${docMismatches.join(", ")}`);
}

summary.push({
  Item: "Founder Wallet",
  Expected: expectedFounder || "(missing)",
  Observed: formatMap(founderMatches),
  Status: founderStatus,
});
summary.push({
  Item: "Token Address",
  Expected: expectedToken || "(missing)",
  Observed: formatMap(tokenMatches),
  Status: tokenStatus,
});
summary.push({
  Item: "Docs",
  Expected: `${expectedFounder || "-"} / ${expectedToken || "-"}`,
  Observed: docMismatches.length > 0 ? docMismatches.join(", ") : "aligned",
  Status: docMismatches.length > 0 ? "mismatch" : "ok",
});

console.log("\nAddress validation summary\n");
console.table(summary);

if (issues.length > 0) {
  console.error("\nIssues detected:");
  issues.forEach((issue) => console.error(`- ${issue}`));
  process.exit(1);
}

console.log("\nAll tracked addresses are consistent.\n");
