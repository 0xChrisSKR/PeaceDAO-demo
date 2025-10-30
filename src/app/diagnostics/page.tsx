'use client';
import { ENV } from '@/lib/env';
import Link from 'next/link';
export default function DiagnosticsPage() {
  return (
    <main style={{padding:20}}>
      <h1>Diagnostics</h1>
      <pre style={{background:'#111',color:'#0f0',padding:12,borderRadius:8}}>{JSON.stringify(ENV,null,2)}</pre>
      <p><Link href="/">Home</Link> · <a href="/api/peace/config">/api/peace/config</a></p>
    </main>
  );
}
