# Default-deny NetworkPolicies for all application namespaces.
# These are enforced by Cilium at the eBPF level (pod-to-pod within the cluster).
# MikroTik handles inter-VLAN routing; these policies handle intra-cluster isolation.
#
# Pattern per namespace:
#  1. deny-all  — blocks all ingress AND egress by default
#  2. allow-dns — pods need port 53 to resolve service names
#  3. allow-from-ingress — Traefik (in kube-system/traefik namespace) can reach the pods
#
# Add more specific allow rules next to each app's manifest.
# ---

{% for ns in ["owncloud","immich","jellyfin","synapse","vaultwarden","grafana",
              "paperless","authentik","router-dashboard","minio","postgresql"] %}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: {{ ns }}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: {{ ns }}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-traefik
  namespace: {{ ns }}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
{% endfor %}
