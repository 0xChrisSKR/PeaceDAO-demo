import "./globals.css";
import Providers from '@/app/providers';
import type { ReactNode } from "react";
import Header from "../components/Header";

export const metadata = { title: "World Peace DAO" };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh">
      <body className="bg-slate-50 text-slate-900"><Providers>
        <Header />
        <main className="mx-auto max-w-5xl p-6">{children}</main>
      </Providers></body>
    </html>
  );
}
