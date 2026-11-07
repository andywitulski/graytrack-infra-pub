# Evidence

How acceptance test results are captured. Real evidence is kept in a private repository, because it names hosts, addresses and accounts. This folder holds **redacted samples** to show the format.

## Rules

1. Save raw output as `YYYY-MM-DD-<subject>.txt`.
2. Include the date, tester, source and commit.
3. Redact secrets, including tokens that appear in URLs.
4. Do not edit results. If a test failed, keep the failure and add the follow-up.
5. Never commit evidence containing real addresses, serials, MAC addresses or account names to a public repository.

## Samples

| File | Shows | ATP |
|---|---|---|
| [sample-edge-dmz-isolation.txt](sample-edge-dmz-isolation.txt) | `edge01` reaches its backend and cannot pivot | ATP-004 |
| [sample-wazuh-first-alert.txt](sample-wazuh-first-alert.txt) | A failed SSH login detected with framework tags | ATP-008 |
