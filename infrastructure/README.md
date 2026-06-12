# Infrastructure as Code

Declarative provisioning for the homelab, replacing the old manual Proxmox
clicking and in-guest `curl | bash` scripts.

```
infrastructure/
  terraform/
    proxmox/   # bpg/proxmox: VMs (Talos + gameserver) + LXCs, image download
    talos/     # siderolabs/talos: machine config, bootstrap, kubeconfig
```

## Order — run from your workstation

The whole stack comes up with one command (see `Makefile`):

```bash
cd infrastructure
make all        # = firewall -> infra -> cluster -> gitops
```

Or step by step:

```bash
make firewall   # 0. open inter-VLAN ports on the UDM Pro (Ansible/UniFi API)
make infra      # 1. create LXCs + Talos VMs via the Proxmox API (auto-start)
make cluster    # 2. Talos config + etcd bootstrap; writes kubeconfig/talosconfig
make gitops     # 3. install Argo CD + apply kubernetes/bootstrap/root-app.yaml
```

After `make gitops`, Argo CD's app-of-apps owns the cluster and syncs
`../kubernetes/platform` and `../kubernetes/apps` automatically.

Run from a machine (your PC) that can reach the Proxmox API (`:8006`), the Talos
API on VLAN 25 (`:50000`) and the Kubernetes API (`:6443`). **Not** the Proxmox
host and **not** a hand-built LXC — see `../docs/proxmox-iac.md`.

## Secrets

- Real `*.tfvars` are git-ignored; copy each `terraform.tfvars.example`.
- Terraform **state contains secrets** (Talos PKI). Use an encrypted remote
  backend or keep state out of git (already ignored).
- Use a least-privilege Proxmox API **token**, not a password.
- In-cluster secrets use Sealed Secrets under `../kubernetes/common/sealed-secrets`.

See `../docs/proxmox-iac.md` for the full design and migration plan.
