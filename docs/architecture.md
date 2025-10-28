# Architecture
Token → Role (PeaceGate) → Chat/Vote (off-chain UIs) → Execute (Timelock/Safe)

- PeaceGate: manages thresholds, blacklist, and emits events for bots.
- PeaceDAO: proposal lifecycle (create → vote → execute) with quorum logic.
- Integrations: Guild/Collab.Land for chat gating, Snapshot/Tally for voting, Gnosis Safe for treasury execution.

## Reference Addresses / 參考地址
- Founder Wallet / 創辦人錢包：`0xD05d14e33D34F18731F7658eCA2675E9490A32D3`
- Governance Token ($世界和平) / 治理代幣：`0x4444def5cf226bf50aa4b45e5748b676945bc509`
