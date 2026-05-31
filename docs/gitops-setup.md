# GitOps Setup Guide

This document explains how to install and use this finished GitOps repository to bootstrap
and operate the homelab cluster. The steps below are copy-paste friendly command lines you
can run from a machine with `kubectl` access to the target cluster.

Prerequisites
-------------

- `kubectl` configured for the target K3s cluster
- `argocd` CLI (optional but useful)
- `kubeseal` CLI for sealing secrets locally
- Network connectivity from the cluster to the public manifests used below

Quick install flow (commands)
-----------------------------

1) Install Longhorn

```bash
kubectl create namespace longhorn-system || true
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
kubectl -n longhorn-system wait --for=condition=Ready pod -l app=longhorn --timeout=10m
```

2) Apply this repository's StorageClass

```bash
kubectl apply -f kubernetes/platform/longhorn-storageclass.yaml
kubectl get storageclass longhorn
```

3) Install Argo CD

```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait --for=condition=Ready deploy/argocd-server --timeout=5m
```

4) Access Argo CD and login locally

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443 &
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$ARGOCD_PASSWORD"
```

5) Register repo and sync platform

```bash
argocd repo add <REPO_URL>
argocd app create homelab-platform \
  --repo <REPO_URL> \
  --path kubernetes/platform \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
argocd app sync homelab-platform
```

6) Install Sealed Secrets and create a sealed secret

```bash
kubectl create namespace sealed-secrets || true
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

kubectl create secret generic db-creds --from-literal=username=postgres --from-literal=password=change_me -n default --dry-run=client -o yaml > secret.yaml
kubeseal --format yaml < secret.yaml > kubernetes/common/sealed-secrets/db-creds-sealed.yaml
git add kubernetes/common/sealed-secrets/db-creds-sealed.yaml && git commit -m "add sealed db creds" && git push
```

7) Create and sync application set

```bash
argocd app create homelab-apps \
  --repo <REPO_URL> \
  --path kubernetes/apps \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
argocd app sync homelab-apps
```

Repo layout (reference)
-----------------------

- `kubernetes/platform/` — cluster bootstrap and platform manifests (Longhorn, ingress, Argo CD apps)
- `kubernetes/common/` — shared namespaces, sealed secrets, and reusable objects
- `kubernetes/apps/` — application manifests and Argo CD Application definitions

Operational notes and recommendations
------------------------------------

- Longhorn replica behavior: `numberOfReplicas: 2` creates two Longhorn replicas of the block
  device. On a single physical server both replicas will live on the same host and will not
  protect against host failure. Add more hosts to gain cross-host durability.
- MinIO redundancy: MinIO's internal replication/erasure coding is separate from Longhorn. You
  may wish to configure both depending on your redundancy and backup goals.
- Use Argo CD for all changes: update manifests in the repo and let Argo CD apply them.

