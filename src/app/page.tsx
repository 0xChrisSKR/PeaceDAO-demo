"use client";
import Link from "next/link";
import ConnectWallet from "../components/ConnectWallet";

export default function HomePage() {
  return (
    <div className="min-h-[70vh] flex flex-col items-center justify-center space-y-6">
      <img src="/assets/logo.png" alt="World Peace DAO" width="96" height="96" className="rounded-full shadow-md" />
      <h1 className="text-4xl font-bold text-center">世界和平 DAO</h1>
      <p className="text-slate-600 text-center max-w-xl">
        去中心化慈善治理平台 🌏<br />
        使用 BNB 進行透明捐贈，社群共同決策提案、投票與驗證。
      </p>
      <div className="flex gap-3">
        <Link href="/donate" className="rounded-full bg-emerald-500 hover:bg-emerald-600 text-white px-5 py-2 font-semibold shadow">
          立即捐贈
        </Link>
        <Link href="/treasury" className="rounded-full bg-sky-500 hover:bg-sky-600 text-white px-5 py-2 font-semibold shadow">
          金庫狀態
        </Link>
      </div>
      <div className="pt-6">
        <ConnectWallet />
      </div>
    </div>
  );
}
