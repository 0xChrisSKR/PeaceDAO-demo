# Architecture
Token → Role (PeaceGate) → Chat/Vote (off-chain UIs) → Execute (Timelock/Safe)

- PeaceGate: manages thresholds, blacklist, and emits events for bots.
- PeaceDAO: proposal lifecycle (create → vote → execute) with quorum logic.
- Integrations: Guild/Collab.Land for chat gating, Snapshot/Tally for voting, Gnosis Safe for treasury execution.
