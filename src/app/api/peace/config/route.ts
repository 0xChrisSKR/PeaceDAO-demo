import { NextResponse } from 'next/server';
import { ENV } from '@/lib/env';
export async function GET() {
  return NextResponse.json({ ok:true, ...ENV, timestamp: Date.now() });
}
