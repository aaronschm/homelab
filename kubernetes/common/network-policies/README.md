# NetworkPolicies — Default-deny for all application namespaces

Each namespace gets three auto-generated policies:
1. **deny-all** — block all ingress + egress (catch-all baseline)
2. **allow-dns** — pods can reach CoreDNS on port 53
3. **allow-from-ingress-controller** — Traefik can reach app pods on their service port

Cilium (`policyEnforcementMode: default`) enforces these at the eBPF level.
MikroTik handles inter-VLAN routing but has no visibility into pod-to-pod
traffic within the cluster — NetworkPolicies are the only intra-cluster mechanism.

## Files

- `default-deny.yaml` — generated default-deny + allow-dns + allow-from-traefik
  for 11 namespaces (owncloud, immich, jellyfin, synapse, vaultwarden, grafana,
  paperless, authentik, router-dashboard, minio, postgresql)
- `app-allow-rules.yaml` — per-app egress allow rules (PostgreSQL, Redis, MinIO, SMTP)
- `kustomization.yaml` — wires both files above

The Jinja2 template that generated `default-deny.yaml` is in
`docs/default-deny.yaml.tpl` for reference — it is not applied by Kubernetes.

## Adding a new namespace

Copy a deny-all + allow-dns block from `default-deny.yaml` and substitute the
namespace name. Add app-specific egress rules to `app-allow-rules.yaml`.