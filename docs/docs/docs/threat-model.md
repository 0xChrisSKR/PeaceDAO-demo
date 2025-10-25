# Threat Model
- Impersonation (fake admins): mitigated via token-verified roles + blacklist.
- Vote weight manipulation: prefer Snapshot-based voting.
- Admin key risk: use multisig + timelock for parameter changes/treasury ops.
- Phishing: only publish official links; educate users in README.
