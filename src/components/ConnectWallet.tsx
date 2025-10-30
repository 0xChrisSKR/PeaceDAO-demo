"use client";
import { useEffect, useState } from "react";

type EthereumProvider = {
  request: (args: { method: string }) => Promise<string[]>;
};

declare global {
  interface Window {
    BinanceChain?: EthereumProvider;
    ethereum?: EthereumProvider;
  }
}

export default function ConnectWallet() {
  const [address, setAddress] = useState<string | null>(null);

  useEffect(() => {
    const provider = window.ethereum ?? window.BinanceChain;
    if (!provider) return;
    provider
      .request({ method: "eth_accounts" })
      .then((accounts) => {
        if (accounts && accounts.length > 0) {
          setAddress(accounts[0]);
        }
      })
      .catch((err) => console.error(err));
  }, []);

  async function connect() {
    if (typeof window === "undefined") return;

    if (window.BinanceChain) {
      try {
        const accounts = await window.BinanceChain.request({ method: "eth_requestAccounts" });
        if (accounts?.length) {
          setAddress(accounts[0]);
          return;
        }
      } catch (err) {
        console.error(err);
      }
    }

    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        if (accounts?.length) {
          setAddress(accounts[0]);
        }
      } catch (err) {
        console.error(err);
      }
    } else {
      alert("請安裝 Binance Web3 或 Metamask 錢包！");
    }
  }

  return (
    <button
      onClick={connect}
      className="rounded-full bg-amber-500 hover:bg-amber-600 text-white px-5 py-2 font-semibold shadow"
    >
      {address ? `已連結: ${address.slice(0, 6)}...${address.slice(-4)}` : "連結錢包"}
    </button>
  );
}
