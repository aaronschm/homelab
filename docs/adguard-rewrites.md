# AdGuard Home DNS Rewrites

AdGuard Home runs on CT 20099 at `10.10.20.99:3000`.

## Configured Rewrites

| Domain | Answer | Purpose |
|--------|--------|---------|
| `*.isarcloud.eu` | `10.10.24.10` | All apps via the managed Traefik edge |
| `*.dlrg.isarcloud.eu` | `10.10.24.10` | Nested DLRG app hostnames via the managed Traefik edge |
| `metrics.isarcloud.eu` | `10.10.24.10` | Explicit override so DNS blocklists cannot sinkhole Grafana |
| `isarcloud.eu` | `10.10.24.10` | Root domain |
| `proxmox.lan` | `10.10.20.2` | Proxmox VE UI |
| `adguard.lan` | `10.10.20.99` | AdGuard admin UI |
| `registry.lan` | `10.10.20.2` | Zot container registry mirror |

## Re-applying via API

If rewrites are lost, re-add with:

```bash
for domain in "*.isarcloud.eu" "*.dlrg.isarcloud.eu" "metrics.isarcloud.eu" "isarcloud.eu"; do
  curl -X POST http://10.10.20.99:3000/control/rewrite/add \
    -H "Content-Type: application/json" \
    -d "{\"domain\": \"$domain\", \"answer\": \"10.10.24.10\"}"
done
```

## Upstream DNS

- Primary: `10.10.1.1` (router, internet-facing)
- Fallback: `https://cloudflare-dns.com/dns-query` (DoH)
