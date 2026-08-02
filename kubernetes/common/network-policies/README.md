# Default-deny NetworkPolicies for every application namespace.
# Each namespace gets:
#   1. deny-all ingress + egress (catch-all)
#   2. allow-dns: pods can reach kube-dns (CoreDNS) on port 53
#   3. allow-ingress-controller: Traefik can reach app pods on their service port
#
# Cilium (policyEnforcementMode: default) enforces these at the eBPF level.
# MikroTik handles inter-VLAN routing but has no visibility into pod-to-pod
# traffic within the cluster — NetworkPolicies are the only mechanism there.
#
# Add namespace-specific allow rules in the relevant app's kustomization or
# a dedicated policy file alongside the app manifest.

{% set namespaces = [
  "owncloud", "immich", "jellyfin", "synapse", "vaultwarden",
  "grafana", "paperless", "authentik", "router-dashboard",
  "minio", "postgresql"
] %}
