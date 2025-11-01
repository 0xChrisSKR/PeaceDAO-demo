// app/config/route.ts
export const dynamic = 'force-static';        // 產生靜態輸出（可快取）
export const revalidate = 60;                 // 60 秒 ISR（改了很快就更新）

export async function GET() {
  const payload = {
    token: 'WORLDPEACE',
    branding: {
      hero: 'Make World Peace Real — On-chain Charity.',
      pitch: 'Every swap funds peace. Transparent, auditable, unstoppable.'
    },
    thresholds: {
      proposer: 1_000_000,
      voter: 200_000,
      verifier: 15_000          // ★ 你要的 15,000 門檻
    },
    feeBps: { min: 5, max: 40, default: 25 },
    treasury: {
      network: 'BSC Mainnet',
      fundAddress: '0x071B1baf97D85a70A6Ca786E7Fe90b45f50464e5'
    },
    community: {
      website: 'https://REPLACE_WEBSITE',
      x: 'https://x.com/REPLACE',
      telegram: 'https://t.me/REPLACE',
      discord: 'https://discord.gg/REPLACE',
      github: 'https://github.com/0xChrisSKR',
      gitbook: 'https://REPLACE_GITBOOK',
      cmc: 'https://coinmarketcap.com/currencies/REPLACE',
      coingecko: 'https://www.coingecko.com/en/coins/REPLACE'
    }
  };

  return Response.json(payload, {
    headers: { 'Cache-Control': 'public, max-age=60, s-maxage=300' }
  });
}
