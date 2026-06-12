# Pelican (game-server management)

Two pieces, intentionally split:

| Piece | Where | What |
|-------|-------|------|
| **Panel** | Kubernetes (`kubernetes/apps/pelican-panel`) | Web UI / API. Stores its data in the in-cluster PostgreSQL and a Longhorn PVC. |
| **Wings** | Gameserver VM `24020` (Terraform) | The daemon that launches game-server **Docker containers**. Kept off the cluster so game I/O never competes with Kubernetes. |

## Bring-up order

1. `make secrets` applies `pelican-panel-secret.yaml` (APP_KEY + DB password).
2. In PostgreSQL, create the panel's role + database (one-time):
   ```sql
   CREATE ROLE pelican LOGIN PASSWORD '<DB_PASSWORD from the secret>';
   CREATE DATABASE pelican OWNER pelican;
   ```
3. Argo CD deploys the Panel. Reach it via the Traefik LXC / an Ingress.
4. In the Panel UI: create a **Node** pointing at the Wings VM
   (`10.10.24.20`), then copy the generated node configuration into
   `/etc/pelican/config.yml` on the VM and `systemctl enable --now wings`.

cloud-init on the VM already installed Docker, the Wings binary and the
(disabled) `wings.service` unit, so only the config paste + enable is left.

## Backups

Game data on the Wings VM lives on the beta SSD (200 GB). Back it up to MinIO,
e.g. a cron'd `mc mirror /var/lib/pelican minio/gameserver-backups` (the same
in-cluster MinIO that receives the Longhorn backups), so it also lands off-site.
