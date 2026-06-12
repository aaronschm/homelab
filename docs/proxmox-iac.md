# Proxmox API IaC + Talos — design & migration

This document describes the API-driven provisioning flow that replaced the manual
Proxmox setup and the old in-guest `curl | bash` bootstrap scripts (now removed).

## Why

The original flow created VMs/LXCs by hand in the Proxmox UI, then configured
them by piping shell scripts over HTTP from an Admin LXC + apt-cacher "update
server". It was non-idempotent, distributed a cluster token in plaintext, and
trusted unverified `curl | bash`.

The new flow is declarative and re-runnable:

- **Terraform `bpg/proxmox`** provisions **VMs and LXC containers** via the
  Proxmox API (`infrastructure/terraform/proxmox`).
- **Talos Linux** is the cluster node OS — an immutable, API-managed OS that
  ships **upstream Kubernetes**. No SSH, no apt, no apt-cacher, no nginx load
  balancer. Bootstrapped by the `siderolabs/talos` provider
  (`infrastructure/terraform/talos`). Single control plane (not HA, by choice).
- **LXCs** (registry, DMZ Traefik, utility) remain Proxmox CTs, declared in
  `infrastructure/terraform/proxmox/lxc.tf`.
- **Utility VMs** (e.g. the Pelican Wings gameserver) import the Debian
  genericcloud image and are configured by cloud-init — no separate template
  build step (`infrastructure/terraform/proxmox/gameserver-vms.tf`).
- **Argo CD app-of-apps** manages everything in-cluster
  (`kubernetes/bootstrap/`).

## Provider choice

| Option | Verdict |
|---|---|
| `bpg/proxmox` | **Chosen.** Native VM + LXC, cloud-init, image import, active. |
| `Telmate/proxmox` | Rejected: weaker LXC support, noisy diffs. |
| Ansible `community.general.proxmox*` | Optional post-provision config only. |
| `siderolabs/talos` | **Chosen** for declarative cluster bootstrap. |

## Proxmox & network prerequisites (node `pve`)

These are the host-side facts and one-time setup the IaC assumes. Current node
(Proxmox VE 9.2.3): single uplink `nic2` → bridge `vmbr0` (`10.10.20.2/24`,
gateway `10.10.20.1`), **not VLAN-aware**, running live LXCs 100–107.

### VLAN-aware bridge (required for the 3-VLAN design)

A *VLAN-aware bridge* lets you tag each VM/LXC NIC with a VLAN id on a single
bridge (instead of creating one bridge per VLAN). Your `vmbr0` currently has
**VLAN aware = No**, so every guest sits untagged on VLAN 20 (`10.10.20.0/24`).
The repo's DMZ (24) and Cluster (25) VLANs won't work until both sides are set:

1. **Proxmox:** Datacenter → `pve` → System → Network → select `vmbr0` → **Edit**
   → tick **VLAN aware** → **Apply Configuration**. This is non-disruptive to
   existing untagged guests (they stay on the native VLAN), but do it during a
   maintenance window since it reloads networking on the only uplink.
2. **UDM Pro:** make the switch port feeding `nic2` a **trunk** carrying VLANs
   20/24/25 (tagged), and create the VLAN networks with gateways `10.10.24.1` /
   `10.10.25.1` (VLAN 25 with no internet — the dark VLAN).

Then keep `enable_vlan_tagging = true` (default) in `terraform.tfvars`.

> **Transition option:** if you're not ready for VLANs, set
> `enable_vlan_tagging = false` and the guests deploy untagged on `vmbr0`. The
> dark-VLAN security model and the 10.10.24/25 IPs only apply once VLANs exist.

### Storage mapping

| tfvars var | Pool | Notes |
|---|---|---|
| `vm_storage` | **beta** | 1 TB ext4 SSD — Talos VM disks (fast for etcd). |
| `ct_storage` | **beta** | LXC rootfs. |
| `image_storage` | **local** | Directory storage — holds ISOs + cloud-init **snippets**. ZFS pools (alpha/beta) can't store those content types. |
| `worker_data_disks[0]` | **beta** | 200 GB — Longhorn volumes (`/var/mnt/longhorn`). |
| `worker_data_disks[1]` | **alpha** | 1000 GB — interim MinIO (`/var/mnt/alpha`) until gamma. |
| MinIO drives | **gamma (future)** | See storage section — prefer raw passthrough over a Proxmox pool. |

`alpha` (4 TB raidz1) is being repurposed as the **interim MinIO disk** (~1 TB
carved off) until the gamma drives are installed; the rest is winding down.

### Debian 13 (trixie) LXC template — the "volume id"

`lxc_template` is the **OS template tarball**, addressed as
`<storage>:vztmpl/<filename>`. Download it on the node first:

```bash
pveam update
pveam available --section system | grep debian-13
pveam download local debian-13-standard_13.<x>-1_amd64.tar.zst
```

That yields e.g. `local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst` — put the
exact filename in `terraform.tfvars`. (Trixie = Debian 13, matches your choice.)

### Talos factory schematic URL — how to generate it

A *schematic* is a Talos image recipe (which system extensions are baked in).
You define it once; the factory returns a content-addressed **schematic ID**.
Two ways:

**A. Web UI** — go to <https://factory.talos.dev>, choose: Cloud Server →
**Nocloud** → arch amd64 → tick **siderolabs/qemu-guest-agent**,
**siderolabs/iscsi-tools** and **siderolabs/util-linux-tools** (the last two are
required by Longhorn) → it shows your schematic ID and the download URLs.

**B. API (reproducible, scriptable)** — POST the recipe:

```bash
cat > schematic.yaml <<'EOF'
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
      - siderolabs/iscsi-tools
      - siderolabs/util-linux-tools
EOF
curl -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics
# -> {"id":"53513e54bb39202f35694412577a6bc53d484744d35a126e5d42ef34785c0d83", ...}
```

Both yield the same ID for the same recipe — **already generated for you**:
`53513e54bb39202f35694412577a6bc53d484744d35a126e5d42ef34785c0d83`
(qemu-guest-agent + iscsi-tools + util-linux-tools). The image URL Terraform
downloads:

```
https://factory.talos.dev/image/53513e54bb39202f35694412577a6bc53d484744d35a126e5d42ef34785c0d83/v1.13.4/nocloud-amd64.raw.gz
```

The schematic ID is **not a secret** — it's a hash of the recipe — so it's fine
in `terraform.tfvars.example`. Terraform downloads the image once to
`image_storage` and imports it as each VM's disk; Talos config is applied later
by the `talos` module. Add more extensions by extending the recipe and
re-POSTing (then update `talos_image_url`).

> **Note — Debian image vs Talos image:** the gameserver VM imports the Debian
> 13 genericcloud qcow2 (downloaded by Terraform, see `debian_image_url`) and is
> configured by cloud-init. The Talos control-plane/worker VMs do **not** use it —
> they boot the factory nocloud image above.

## Topology (sizing)

| Role | Type | VLAN | Count | vCPU | RAM | Disk |
|---|---|---|---|---|---|---|
| Talos control plane | VM | 25 | **1** (hardware-limited) | 2 | 6 GB | 50 GB |
| Talos worker (+ MinIO + all pods) | VM | 25 | **1** | 6 | **32 GB** | 100 GB OS + data |
| Registry (image mirror) | LXC | 20 | 1 | 1 | 2 GB | 50 GB |
| DMZ Traefik | LXC | 24 | 1 | 1 | 1 GB | 8 GB |
| Gameserver (Wings) | VM | 24 | 1 | 4 | 10 GB | 200 GB (beta) |

Fixed at **1 control plane + 1 worker** per the hardware limit. No kube-vip VIP
is used in this topology (the cluster endpoint points straight at the control
plane); the VIP path is only relevant if you ever scale to 3 control planes.

Retired by this design: **Update Server** (apt-cacher) and **Load Balancer**
(nginx) LXCs — Talos needs neither (no apt; single API endpoint).

## Host resource budget (R7 5800X · 8c/16t · 64 GB)

The 64 GB is the hard constraint. Everything the cluster runs lives on the
**worker** VM, so we size the worker to the realistic concurrent working set of
planned pods, then hand the **leftover** to the gameserver.

**Worker pod budget (steady state, the apps from `docs/roadmap.md`):**

| Workload | ~RAM |
|---|---|
| Longhorn (manager + engines) | 1.5 GB |
| MinIO (interim on alpha) | 2 GB |
| PostgreSQL | 1 GB |
| Argo CD | 1 GB |
| Authentik (server+worker+redis) | 1.5 GB |
| Immich (incl. ML) | 3 GB |
| Nextcloud/ownCloud | 1.5 GB |
| Paperless-ngx | 1 GB |
| Jellyfin (idle; more when transcoding) | 1.5 GB |
| Vaultwarden / AdGuard / Homepage / Uptime-Kuma / Scrutiny | ~1.5 GB total |
| Monitoring (VictoriaMetrics/Grafana/Loki) | 2 GB |
| Pelican Panel | 0.5 GB |
| kube-system + kubelet + headroom | ~3 GB |
| **Subtotal** | **~22 GB** |

So **32 GB** for the worker covers the full planned set with spike headroom (and
keeps MinIO's documented sizing for when the gamma drives come online). The rest
is split so there is always headroom for guests that live on the host but are
**not** in this repo yet — chiefly **Home Assistant OS** (HAOS, with the Bluetooth/
Wi-Fi PCIe card passed through) and any other LXCs you add by hand:

| Consumer | RAM | vCPU |
|---|---|---|
| Proxmox host + ZFS ARC (cap ARC ~4 GB) | ~5 GB | (shared) |
| Control plane VM | 6 GB | 2 |
| Worker VM | 32 GB | 6 |
| Registry LXC | 2 GB | 1 |
| Traefik LXC | 1 GB | 1 |
| **Reserved: HAOS VM** (not in repo) | **4 GB** | 2 |
| **Reserved: other LXCs headroom** | **4 GB** | — |
| **Gameserver VM (leftover)** | **10 GB** | 4 |
| **Total** | **64 GB** | 16 threads |

vCPU is intentionally over-committed — CPU is time-shared and these workloads
rarely peak together; **RAM is the real cap**, so the RAM column sums to the full
64 GB. The two *Reserved* rows are deliberately left unallocated by Terraform so
you can stand up HAOS and ad-hoc LXCs without starving the cluster or gameserver.

> When the **6×18 TB gamma drives** are installed, MinIO will want more RAM
> (24–32 GB just for itself at ~100 TiB). At that point, reclaim from the
> gameserver and/or the reserved pool (e.g. worker 40 GB / gameserver 8 GB), or
> add physical RAM. Until then the gameserver enjoys the surplus.

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

So the worker is sized at **32 GB** (`workers."25101".memory = 32768`). That RAM
is shared with kubelet, MinIO, and your other pods, so 32 GB is the sensible
target; **16 GB is the practical floor** (MinIO runs but with less read caching).
MinIO's official "production" rec of 128 GB is for high-throughput multi-node
clusters and is unnecessary for a homelab single node.

> ⚠️ **Decision / check:** confirm your Proxmox host has enough RAM for
> CP (6) + worker (32) + Registry (2) + Traefik (1) + host overhead (~4) ≈ **45 GB**.
> If the host can't spare 32 GB for the worker, drop it to 16–24 GB and accept
> reduced MinIO caching.

## Cluster storage: Longhorn (beta) + MinIO (alpha, interim)

Two storage systems with different jobs:

| | Backing pool | Mount | StorageClass | Used for |
|---|---|---|---|---|
| **Longhorn** | `beta` SSD | `/var/mnt/longhorn` | `longhorn` (**default**) | App PVCs (databases, app data) |
| **MinIO** | `alpha` (interim) | `/var/mnt/alpha` | `local-path` (non-default) | S3 object store + **Longhorn backup target** |

**Longhorn** is the default StorageClass, installed via an Argo CD Helm app
(`kubernetes/platform/longhorn/longhorn-app.yaml`, chart 1.12.0). Its volumes
live on the **beta** SSD at `/var/mnt/longhorn`. Single worker → **1 replica**
(more would just duplicate on the same node). Longhorn needs the
`iscsi-tools` + `util-linux-tools` Talos system extensions, which is why the
factory schematic was regenerated to include them
(ID `53513e54…`, already in `terraform.tfvars.example`).

**Scheduled off-host backups:** a Longhorn `RecurringJob`
(`kubernetes/platform/longhorn/backup-recurringjob.yaml`) backs up **every 6
hours** (retain 8 ≈ 2 days) to MinIO at `s3://longhorn-backups`. Replicate that
MinIO bucket to your friend's MinIO for the off-site copy — then a beta SSD or
whole-node loss is recoverable from the friend's site.

> The backup chain is **Longhorn → local MinIO → friend's MinIO**. Configure
> MinIO bucket replication (or a periodic `mc mirror`) to the remote once it
> exists; until then backups still protect against volume-level mistakes.

### Interim MinIO on `alpha` (before gamma)

You don't have to wait for the 6×18 TB drives. MinIO runs now on a **1000 GB**
virtual disk carved from the existing **`alpha`** pool:

- Terraform attaches the disk to the worker (`worker_data_disks` entry
  `{ storage = "alpha", size_gb = 1000, mountpoint = "/var/mnt/alpha" }`).
- Talos formats + mounts it and bind-mounts it into the kubelet.
- `local-path-provisioner` hands MinIO a PV there
  (`kubernetes/platform/local-path-provisioner`), and MinIO serves S3 at
  `minio.minio.svc:9000` (`kubernetes/platform/minio`).

**Pods only ever see the S3 endpoint**, so when the gamma drives arrive you swap
the backing store (below) with zero changes to your app manifests — and
Longhorn's backup target stays the same.

### Passing the 6 drives through to the worker (future)

The drives aren't installed yet — this is future work. When you add them, you
have two choices for the **gamma** storage:

- **✅ Recommended: raw disk passthrough** of each physical disk to the worker
  VM. MinIO then does its own erasure coding across the 6 raw drives. This
  avoids ZFS-on-ZFS write amplification and gives MinIO direct control.
- ❌ Wrapping each disk in a Proxmox `gamma_1..gamma_6` ZFS/dir pool and handing
  MinIO virtual disks — adds a filesystem layer under MinIO's own EC for no
  benefit, and costs RAM/CPU. Skip unless you need Proxmox-level snapshots.

bpg cannot cleanly create raw-device passthrough, so attach the physical disks
to the worker VM at the Proxmox level (one-time), then let Talos format/mount
them. List the drives in `minio_disks_by_id` (for documentation) and run, per disk:

```bash
# On the Proxmox host — find stable names first:
ls -l /dev/disk/by-id/   # use ata-/wwn- names, NOT /dev/sdX
# Attach each disk to the worker VM (vmid 25101), as scsi3..scsi8 (scsi1/2 are
# the Longhorn + interim-alpha disks):
qm set 25101 -scsi3 /dev/disk/by-id/ata-<DISK1>
qm set 25101 -scsi4 /dev/disk/by-id/ata-<DISK2>
# ... through the 6th drive
```

Then mount them in Talos by adding entries to `worker_data_disks` (or a dedicated
patch in `infrastructure/terraform/talos/talos.tf`) at `/var/mnt/disk{1..6}`.
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
   the app-of-apps syncs `kubernetes/platform` (Longhorn, local-path, MinIO,
   ingress…) and `kubernetes/apps` automatically. Your in-repo pods come up on
   their own.
4. **`make secrets`** — applies the git-ignored Kubernetes secrets Argo can't
   pull from Git (MinIO root + Longhorn backup creds). Copy each
   `*-secret.example.yaml` to `*-secret.yaml`, edit, then run this (or seal them
   with `kubeseal` and commit the sealed copy for a fully GitOps flow).

After `make all`, a host power-cycle brings everything back automatically: PVE
boots the LXCs/VMs in order → Talos rejoins → Argo CD reconciles to the repo.

## Dark Cluster VLAN: image mirror is mandatory

`docs/network-setup.md` puts VLAN 25 on a **dark VLAN with no internet**. Talos
and Kubernetes still need to pull container images (k8s components, your apps).
The **Registry LXC (`10.10.20.101:5000`) acts as a pull-through mirror** running
**Zot** (`ansible/registry-zot.yml`), and Talos is pointed at it via
`registry_mirror_endpoint` (a `machine.registries.mirrors` patch covering
docker.io, ghcr.io, registry.k8s.io, gcr.io, quay.io). This replaces the old
apt-cacher "update server".

> **Why Zot, not `registry:2`:** a plain `registry:2` can pull-through
> **only one** upstream. Zot's `sync`
> extension proxies **all five** upstreams on demand from a single endpoint.
> Talos maps each registry name to the same Zot URL; Zot resolves the upstream
> per request. Deploy with `ansible-playbook -i inventory.ini registry-zot.yml`
> after `make infra`. (Alternatives considered: Harbor — heavier; multiple
> `registry:2` instances — more moving parts.)

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
> logs in with a **local UniFi admin account** (the Integration API key cannot
> manage firewall policies) and **discovers your zones first** (run it read-only,
> then fill `zone_ids` and re-run with `-e udm_apply=true`). It manages firewall
> *policies* only — create the VLAN networks in the UI. See `ansible/README.md`.

## Phased migration

- **Phase 0 — Safety:** cluster token removed; `.gitignore` covers
  tfvars/state/kubeconfig/ansible secrets. Record current VM specs into `terraform.tfvars`.
- **Phase 1 — Network + provider scaffolding:** run `ansible/udm-firewall.yml` to
  open the inter-VLAN ports on the UDM Pro; create a least-privilege Proxmox API
  token; `terraform -chdir=infrastructure/terraform/proxmox init && plan`.
- **Phase 2 — LXCs declarative:** apply `lxc.tf` for Registry + DMZ Traefik;
  make the Registry a pull-through mirror.
- **Phase 3 — Talos cluster:** build a factory schematic (with
  `qemu-guest-agent`), set `talos_image_url`, pass through the 6 MinIO disks,
  apply `proxmox` then `talos`.
- **Phase 4 — GitOps:** `make gitops` (Argo CD + app-of-apps). Add MinIO to
  `kubernetes/platform`.
- **Phase 5 — Cleanup:** legacy scripts/docs and `cluster.conf` deleted; README
  rewritten for the IaC flow. ✅ done.

## Things easy to overlook (raised for you)

- **Dark-VLAN image pulls** — covered above; without the registry mirror the
  cluster cannot start any pod. Biggest gotcha.
- **No HA — by choice.** 1 CP + 1 worker means node loss = outage; that's
  accepted. etcd lives on the one CP, so **off-box backups still matter**:
  schedule etcd/Talos snapshots, and the Longhorn→MinIO→friend backup chain
  (above) protects volume data. Replicate the MinIO bucket off-site.
- **Storage — Longhorn default + local-path for MinIO.** Longhorn (chart 1.12.0,
  via Argo Helm app) is the **default StorageClass**, on the beta SSD at
  `/var/mnt/longhorn`, 1 replica, with 6-hourly backups to MinIO. It needs the
  `iscsi-tools` + `util-linux-tools` Talos extensions (baked into the regenerated
  schematic `53513e54…`). `local-path` is a **non-default** class used only by
  MinIO on the interim `alpha` disk. See the storage section.
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

### Secrets in a GitOps repo (MinIO root, Longhorn backup creds)

Plain manifests live in Git, but **secrets must not**. Two facts collide:
Argo CD applies *only what's in Git*, yet you can't commit plaintext secrets.
The repo handles this with a template + git-ignore pattern:

- `*-secret.example.yaml` (committed) — placeholder templates. Argo **excludes**
  them (`directory.exclude: "**/*.example.yaml"`) so it never applies placeholders.
- `*-secret.yaml` (git-ignored) — the real secret you create locally.

To deploy the real secret, pick one:

- **Manual (simple):** `cp x-secret.example.yaml x-secret.yaml`, edit, then
  `make secrets` (`kubectl apply`). Quick, but the secret lives only on your PC +
  the cluster, not in Git — fine for a homelab.
- **Sealed Secrets (GitOps-native, recommended long-term):** `kubeseal` encrypts
  the secret into a `SealedSecret` that **is safe to commit**; Argo applies it and
  the in-cluster controller decrypts it. This keeps the "everything in Git" model
  without leaking plaintext. Install the sealed-secrets controller (add it to
  `kubernetes/platform`) and seal MinIO + Longhorn creds when you're ready.

## Decisions still open (flagged)

- **VLAN-aware bridge + UDM trunk** — `vmbr0` is VLAN-aware ✓ and VLANs 20/24/25
  exist ✓. Remaining: confirm the UDM **switch port to the Proxmox host is a
  trunk** carrying VLANs 20/24/25 (tagged). Otherwise tagged guest traffic won't
  pass and the nodes won't get their VLAN IPs.
- **Worker RAM vs host capacity** — confirm the host can give the worker 32 GB
  alongside the CP + LXCs (see MinIO section). Fallback 16–24 GB.
- **UDM auth — local admin login.** Firewall policy CRUD uses the internal v2
  API, authenticated with a local UniFi admin account (not the Integration API
  key). Validate the schema via discovery mode (`ansible/README.md`).
- **Secrets manager:** for Terraform — SOPS+age (encrypt tfvars in git) vs
  ignored local tfvars (current default). For Kubernetes — `make secrets` (manual
  apply) vs Sealed Secrets (commit encrypted). Pick before onboarding collaborators.
- **MinIO off-site replication:** configure bucket replication / `mc mirror` from
  your MinIO to your friend's MinIO once it exists (Longhorn backups land in
  `longhorn-backups`).
- **Ingress:** keep DMZ Traefik LXC vs move ingress fully in-cluster.
- **MinIO disk management:** DirectPV vs static Talos mounts + hostPath (drives
  not installed yet — deferred).

## Resolved inputs (node `pve`)

- **Node:** `pve`. **Bridge:** `vmbr0` (VLAN-aware ✓; VLANs 20/24/25 created).
- **Storage:** `vm_storage`/`ct_storage` = `beta` (1 TB SSD); `image_storage` =
  `local` (ISOs + snippets); worker data disks = `beta` 200 GB (Longhorn) +
  `alpha` 1000 GB (interim MinIO) until `gamma` (future 6×18 TB) is built.
- **LXC template:** Debian 13 (trixie) — `pveam download local debian-13-standard…`.
- **Talos schematic:** `53513e54…` — nocloud image with qemu-guest-agent +
  iscsi-tools + util-linux-tools (Longhorn).
- **MinIO drives:** gamma not installed yet; MinIO runs on the interim `alpha`
  data disk now, raw passthrough planned for gamma (`minio_disks_by_id = []`).
