# Plan the public mail edge

> **Status: proposed, not built.** The [mail hub](mail.md) runs today. In this stage a small VPS becomes the public MX and outbound relay **in front of** the hub over the tailnet, so mailboxes stay on site and only the internet-facing edge is rented. `tofu/cloud/prod` and `bin/tf-cloud` exist. The VPS configuration must be rewritten for the relay role before this is built.

**Goal:** Send and receive on your own domain despite a residential ISP blocking outbound port 25.

**Why:** [ADR-0013](../adr/0013-mail-hub-and-public-edge.md).

If your domain's mail is currently hosted elsewhere, this is a **migration**: change records in one planned cutover, after the relay works for a test domain.

| Piece | Design |
|---|---|
| VPS | Small ARM instance, Debian 13, `tofu/cloud/prod` |
| Public | Mail ports and ACME only; SSH and admin UI over the tailnet |
| Management | Joins Headscale on first boot |
| Secrets | `secrets/cloud-prod.enc.env`: `HCLOUD_TOKEN`, state passphrase, tailnet key |

## Decide about deliverability first

A new IP has no reputation and often lands in spam for weeks.

| Option | Description | Use when |
|---|---|---|
| A. Direct send | Requires SPF, DKIM, DMARC, matching PTR, MTA-STS, warm-up | You can tolerate early spam placement |
| B. Smarthost | The server sends **as** you through a relay with reputation | **Mail that matters. Recommended to start** |

You can start with B and move to A once the IP is warm, with no change of address.

## Outline

1. **Secrets and state.** Create the encrypted env file and a `cloud` schema on `pg01`.
2. **Pre-auth key** on `hs01`: single use, one hour.
   ```bash
   ssh ansible@hs01 'sudo headscale preauthkeys create --user 1 --expiration 1h --output json' | jq -r .key
   ```
3. **Create the VPS.** It appears in `headscale nodes list`. Leave it out of `headscale_trusted_devices`: it is a server that needs no lab access.
   ```bash
   bin/tf-cloud prod plan && bin/tf-cloud prod apply
   ```
4. **DNS records.**

   | Type | Name | Value |
   |---|---|---|
   | A, AAAA | `mail` | VPS addresses |
   | MX | `@` | `10 mail.example.com.` |
   | TXT | `@` | `v=spf1 mx -all` |
   | TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; adkim=s; aspf=s` |
   | TXT | `_smtp._tls` | `v=TLSRPTv1; rua=mailto:tlsrpt@example.com` |
   | TXT | `_mta-sts` | `v=STSv1; id=1` |
   | CNAME | `mta-sts` | `mail.example.com.` |
   | TXT | `<selector>._domainkey` | DKIM key from the server |

   OpenTofu sets the PTR. It must match, or receivers reject.
5. **Check.** Send to an external address and read the headers for SPF, DKIM and DMARC pass. Aim for 9/10 or better on a mail-testing service before relying on it.
   ```bash
   swaks --to alice@example.com --server mail.example.com
   ```

## Operate

- Watch DMARC reports, and move to `p=reject` when they are clean.
- **Backups:** snapshot the VPS. It is outside PBS and DR scope; its loss never touches the lab. Keep the provider login and DKIM key in the recovery kit.
- **VPS lost:** rebuild, restore data, re-point `ansible_host`, and update A, AAAA and PTR. Expect a short warm-up.
