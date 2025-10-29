#!/usr/bin/env node
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';

const allowedLinks = new Set([
  'https://t.me/WorldPeace_BNB',
  'https://t.me/+i-dpunM-luk1ZjRl',
]);

const repoRoot = process.cwd();
const occurrences = new Map();

function recordOccurrence(link, filePath, lineNumber) {
  if (!occurrences.has(link)) {
    occurrences.set(link, []);
  }
  occurrences.get(link).push({ filePath, lineNumber });
}

function walk(currentPath) {
  const entries = readdirSync(currentPath, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === 'node_modules' || entry.name === '.git') {
      continue;
    }
    const fullPath = path.join(currentPath, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath);
    } else if (entry.isFile() && path.extname(entry.name).toLowerCase() === '.md') {
      scanFile(fullPath);
    }
  }
}

function scanFile(filePath) {
  const relativePath = path.relative(repoRoot, filePath);
  const content = readFileSync(filePath, 'utf8');
  const lines = content.split(/\r?\n/);
  const regex = /https:\/\/t\.me\/[A-Za-z0-9_+\-]+/g;
  lines.forEach((line, index) => {
    const matches = line.match(regex);
    if (matches) {
      for (const link of matches) {
        recordOccurrence(link, relativePath, index + 1);
      }
    }
  });
}

walk(repoRoot);

const foundLinks = new Set(occurrences.keys());
const missingLinks = Array.from(allowedLinks).filter((link) => !foundLinks.has(link));
const unexpectedLinks = Array.from(foundLinks).filter((link) => !allowedLinks.has(link));

if (missingLinks.length === 0 && unexpectedLinks.length === 0) {
  console.log('✅ Telegram link validation passed.');
  process.exit(0);
}

console.error('❌ Telegram link validation failed.');
if (missingLinks.length > 0) {
  console.error('\nMissing canonical links:');
  missingLinks.forEach((link) => {
    console.error(`  - ${link}`);
  });
}

if (unexpectedLinks.length > 0) {
  console.error('\nUnexpected Telegram links found:');
  unexpectedLinks.forEach((link) => {
    console.error(`  - ${link}`);
    const details = occurrences.get(link) || [];
    details.forEach(({ filePath, lineNumber }) => {
      console.error(`      • ${filePath}:${lineNumber}`);
    });
  });
}

process.exit(1);
