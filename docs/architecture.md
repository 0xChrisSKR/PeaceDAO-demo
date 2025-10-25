# Architecture
Token → Role (PeaceGate) → Chat/Vote (off-chain UIs) → Execute (Timelock/Safe)

- PeaceGate: thresholds for read/vote/propose; blacklist; events for bots.
- PeaceDAO: proposals, votes, quorum; optional Snapshot IDs.
- Integrations: Guild/Collab.Land (chat gating), Snapshot/Tally (voting), Safe+Timelock (treasury).
