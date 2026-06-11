# Proxmox API IaC + Talos — design & migration

This document describes the API-driven provisioning flow that replaces the manual
Proxmox setup and the in-guest bootstrap scripts (`scripts/*.sh`,
`docs/update-server-setup.md`, `docs/load-balancer-setup.md`, `docs/k3s-setup.md`).

## Why

The original flow created VMs/LXCs by hand in the Proxmox UI, then configured
them by piping shell scripts over HTTP from an Admin LXC + apt-cacher "update
server". It was non-idempotent, distributed a cluster token in plaintext
(`cluster.conf`), and trusted unverified `curl | bash`.

The new flow is declarative and re-runnable:

- **Terraform `bpg/proxmox`** provisions **VMs and LXC containers** via the
  Proxmox API (`infrastructure/terraform/proxmox`).
- **Talos Linux** replaces Debian + k3s for cluster nodes — an immutable,
  API-managed OS. No SSH, no apt, no apt-cacher, no nginx load balancer
  (control-plane HA is a `kube-vip` VIP). Bootstrapped by the
  `siderolabs/talos` provider (`infrastructure/terraform/talos`).
- **LXCs** (registry, DMZ Traefik, utility) remain Proxmox CTs, declared in
  `infrastructure/terraform/proxmox/lxc.tf`.
- **Packer** builds a cloud-init Debian template for non-Talos utility VMs such
  as the Gameserver (`infrastructure/packer/debian`).
- **Argo CD app-of-apps** manages everything in-cluster
  (`kubernetes/bootstrap/`).

## Provider choice

| Option | Verdict |
|---|---|
| `bpg/proxmox` | **Chosen.** Native VM + LXC, cloud-init, image import, active. |
| `Telmate/proxmox` | Rejected: weaker LXC support, noisy diffs. |
| Ansible `community.general.proxmox*` | Optional post-provision config only. |
| `siderolabs/talos` | **Chosen** for declarative cluster bootstrap. |

## Topology (sizing)

| Role | Type | VLAN | Count | vCPU | RAM | Disk |
|---|---|---|---|---|---|---|
| Talos control plane | VM | 25 | **1** (hardware-limited) | 2 | 6 GB | 50 GB |
| Talos worker (+ MinIO) | VM | 25 | **1** | 5 | **32 GB** | 100 GB OS + 6×18 TB passthrough |
| Registry (image mirror) | LXC | 20 | 1 | 1 | 2 GB | 50 GB |
| DMZ Traefik | LXC | 24 | 1 | 1 | 1 GB | 8 GB |
| Gameserver (Wings) | VM | 24 | 1 | per game | — | — |

Fixed at **1 control plane + 1 worker** per the hardware limit. No kube-vip VIP
is used in this topology (the cluster endpoint points straight at the control
plane); the VIP path is only relevant if you ever scale to 3 control planes.

Retired by this design: **Update Server** (apt-cacher) and **Load Balancer**
(nginx) LXCs — Talos needs neither (no apt; single API endpoint).

> Note on terminology: "k3s" here is replaced by **Talos + upstream Kubernetes**.
> Talos is the node OS; Kubernetes is the orchestrator that runs your in-repo
> pods. There is no k3s binary in the new flow.

## MinIO storage: 6×18 TB + RAM sizing

You're putting all six 18 TB drives into one node as **separate drives** (no
hardware RAID). MinIO running as **Single-Node Multi-Drive (SNMD)** then applies
its own erasure coding *across* those 6 drives, giving you drive-failure
tolerance (you can lose up to 2 of the 6 and keep serving) without a RAID
controller. Raw ≈ 108 TB; usable after default EC ≈ **~72 TB**.

**RAM:** MinIO's memory use scales with usable capacity and concurrency. For
~100 TiB of storage:

| Usable storage | Comfortable RAM for MinIO |
|---|---|
| ≤ 10 TiB | 16 GB |
| ~100 TiB (your case) | **24–32 GB** |
| ≥ 1 PiB | 64 GB+ |

So the worker is sized at **32 GB** (`workers.worker-1.memory = 32768`). That RAM
is shared with kubelet, Longhorn, and your other pods, so 32 GB is the sensible
target; **16 GB is the practical floor** (MinIO runs but with less read caching).
MinIO's official "production" rec of 128 GB is for high-throughput multi-node
clusters and is unnecessary for a homelab single node.

> ⚠️ **Decision / check:** confirm your Proxmox host has enough RAM for
> CP (6) + worker (32) + Registry (2) + Traefik (1) + host overhead (~4) ≈ **45 GB**.
> If the host can't spare 32 GB for the worker, drop it to 16–24 GB and accept
> reduced MinIO caching.

### Passing the 6 drives through to the worker

bpg cannot cleanly create raw-device passthrough, so attach the physical disks
to the worker VM at the Proxmox level (one-time), then let Talos format/mount
them. List the drives in `minio_disks_by_id` (for documentation) and run, per disk:

```bash
# On the Proxmox host — find stable names first:
ls -l /dev/disk/by-id/   # use ata-/wwn- names, NOT /dev/sdX
# Attach each disk to the worker VM (vmid 2101), as scsi1..scsi6:
qm set 2101 -scsi1 /dev/disk/by-id/ata-<DISK1>
qm set 2101 -scsi2 /dev/disk/by-id/ata-<DISK2>
# ... through scsi6
```

Then mount them in Talos via a machine-config patch (add to the worker patch in
`infrastructure/terraform/talos/talos.tf`):

```yaml
machine:
  disks:
    - device: /dev/sdb   # first passthrough disk
      partitions:
        - mountpoint: /var/mnt/disk1
    # repeat for /dev/sdc.. /var/mnt/disk6
```

MinIO (deployed via Argo CD) then uses `/var/mnt/disk{1...6}` as its drives.
Consider MinIO **DirectPV** for managing these as Kubernetes PVs.

## Where do you start the installation?

**Run it from your workstation (your PC)** — not the Proxmox host, not a
hand-built LXC. Your PC already has the repo, the tooling, and network access to
all the APIs. The Proxmox host stays clean (no Terraform/state on it), and you
avoid the chicken-and-egg of "an LXC to build the LXCs".

Your PC needs: `terraform`, `talosctl`, `kubectl`, and routing to:
the **Proxmox API** (`:8006`), the **Talos API** on VLAN 25 (`:50000`), and the
**Kubernetes API** on VLAN 25 (`:6443`).

Your PC is on **VLAN 10 and VLAN 20**. Both work: Proxmox lives on VLAN 20 (direct
L2), and the Talos/Kubernetes APIs on VLAN 25 are reached via the UDM Pro's
inter-VLAN routing once the firewall rules below exist. You don't need to be on
VLAN 20 specifically — the `ansible/udm-firewall.yml` playbook opens VLAN 10 → the
required ports too.

### One-touch flow (`infrastructure/Makefile`)

```bash
cd infrastructure
make all      # = infra -> cluster -> gitops
```

1. **`make infra`** — Terraform calls the **Proxmox API** to create the Registry
   + Traefik LXCs and the Talos CP + worker VMs. Every guest is created with
   `started = true` and `on_boot = true`, with a boot **startup order**
   (Registry → CP → worker → Traefik), so they auto-start now and on every host
   reboot.
2. **`make cluster`** — Terraform applies Talos machine config, bootstraps etcd,
   and writes `kubeconfig` + `talosconfig` to `infrastructure/` (git-ignored).
3. **`make gitops`** — installs Argo CD and applies
   `kubernetes/bootstrap/root-app.yaml`. From there **Argo CD owns the cluster**:
   the app-of-apps syncs `kubernetes/platform` (Longhorn, MinIO, ingress…) and
   `kubernetes/apps` automatically. Your in-repo pods come up on their own.

After `make all`, a host power-cycle brings everything back automatically: PVE
boots the LXCs/VMs in order → Talos rejoins → Argo CD reconciles to the repo.

## Dark Cluster VLAN: image mirror is mandatory

`docs/network-setup.md` puts VLAN 25 on a **dark VLAN with no internet**. Talos
and Kubernetes still need to pull container images (k8s components, your apps).
The **Registry LXC (`10.10.20.101:5000`) must act as a pull-through mirror**, and
Talos is pointed at it via `registry_mirror_endpoint` (a `machine.registries.mirrors`
patch covering docker.io, ghcr.io, registry.k8s.io, gcr.io, quay.io). This is the
modern replacement for the old apt-cacher "update server".

Required firewall additions — **automated via Ansible against the UDM Pro**
(`ansible/udm-firewall.yml`, rules in `ansible/vars/firewall-rules.yml`). Run it
once before `make all`:

| Source | Destination | Port | Purpose |
|---|---|---|---|
| PC (VLAN 10) | VLAN 20 (Proxmox) | TCP 8006 | Proxmox API |
| PC (VLAN 10) | VLAN 25 nodes | TCP 50000 | Talos API (config/bootstrap) |
| PC (VLAN 10) | VLAN 25 control plane | TCP 6443 | Kubernetes API |
| VLAN 25 nodes | `10.10.20.101` | TCP 5000 | Registry pull-through mirror |
| `10.10.24.10` (Traefik) | VLAN 25 | TCP 80/443 | Ingress |

> Your UDM runs **UniFi Network 10.4.57 → Zone-Based Firewall**. The playbook
> uses the ZBF v2 API with an API key and **discovers your zones first** (run it
> read-only, then fill `zone_ids` and re-run with `-e udm_apply=true`). See
> `ansible/README.md`.

## Phased migration

- **Phase 0 — Safety:** token removed from `cluster.conf`; `.gitignore` covers
  tfvars/state/kubeconfig/ansible secrets. Record current VM specs into `terraform.tfvars`.
- **Phase 1 — Network + provider scaffolding:** run `ansible/udm-firewall.yml` to
  open the inter-VLAN ports on the UDM Pro; create a least-privilege Proxmox API
  token; `terraform -chdir=infrastructure/terraform/proxmox init && plan`.
- **Phase 2 — LXCs declarative:** apply `lxc.tf` for Registry + DMZ Traefik;
  make the Registry a pull-through mirror; retire curl-based bootstrap for those.
- **Phase 3 — Talos cluster:** build a factory schematic (with
  `qemu-guest-agent`), set `talos_image_url`, pass through the 6 MinIO disks,
  apply `proxmox` then `talos`. Retire `scripts/k3s-*.sh`, `update-server`,
  `load-balancer`.
- **Phase 4 — GitOps:** `make gitops` (Argo CD + app-of-apps). Add MinIO to
  `kubernetes/platform`.
- **Phase 5 — Cleanup:** delete obsolete scripts/docs; finalize README.

## Things easy to overlook (raised for you)

- **Dark-VLAN image pulls** — covered above; without the registry mirror the
  cluster cannot start any pod. Biggest gotcha.
- **No HA — by choice.** 1 CP + 1 worker means node loss = outage; that's
  accepted. But MinIO SNMD only survives *drive* loss, and etcd lives on the one
  CP, so **off-box backups still matter**: schedule etcd/Talos snapshots and
  MinIO bucket replication (or restic) to another host/NAS.
- **Longhorn replica count — done.** Set to `1` in
  `kubernetes/platform/longhorn-storageclass.yaml` (single worker; 2 would just
  duplicate on the same node). Bump back up only if you add a second worker.
- **Talos secrets live in Terraform state.** `talos_machine_secrets` (cluster CA,
  etcd PKI, bootstrap token) is written to the `talos` module's `.tfstate`. With
  local state that's a file on your PC — back it up securely; losing it means
  re-bootstrapping the cluster. Encrypt the backend if state ever leaves your PC.
- **Time/NTP.** etcd and TLS are time-sensitive; ensure the dark VLAN has an
  internal NTP source or set Talos `machine.time.servers`.
- **Talos upgrades** are API-driven (`talosctl upgrade`), separate from k8s
  upgrades — plan both.
- **DNS & certificates** for ingress (Traefik ACME) still require VLAN 24
  internet egress, which `network-setup.md` already allows.

## Where your pod manifests live (Git + Argo CD)

Your application/platform YAML **belongs in this repo** — `kubernetes/apps/` and
`kubernetes/platform/`. Argo CD's app-of-apps (`kubernetes/bootstrap/root-app.yaml`)
pulls them from Git and reconciles them onto the cluster. Nothing has to live
outside Git.

The only requirement is that **Argo CD can reach the Git repo it points at**:

- **Public GitHub repo** → no credentials needed; works out of the box.
- **Self-hosted Git LXC** (totally fine) → set `repoURL` to your LXC's URL. If it
  requires auth, give Argo a read-only credential stored as a **Sealed Secret**
  (`kubernetes/common/sealed-secrets/`). That's the *only* "repo access" concern —
  it is not about whether the manifests can be in the repo (they should be).

## Decisions still open (flagged)

- **Worker RAM vs host capacity** — confirm the host can give the worker 32 GB
  alongside the CP + LXCs (see MinIO section). Fallback 16–24 GB.
- **UDM auth confirmed:** API key (`X-API-KEY`). ZBF policy CRUD uses the
  internal v2 API — validate the schema via discovery mode (`ansible/README.md`).
- **Secrets manager:** SOPS+age (encrypt tfvars in git) vs ignored local tfvars
  (current default). Pick one before onboarding collaborators.
- **Ingress:** keep DMZ Traefik LXC vs move ingress fully in-cluster.
- **MinIO disk management:** DirectPV vs static Talos mounts + hostPath.
- **Proxmox specifics to fill into tfvars:** node name, `vmbr` bridge (must be
  VLAN-aware), storage pool names, LXC template volume id, Talos factory
  schematic URL, the 6 disk `by-id` paths.
