# Debian cloud-init template (Packer)

Builds a reusable Debian 13 cloud-init **template** on Proxmox for non-Talos
utility VMs (e.g. the Gameserver / Pelican Wings host). Talos nodes do not use
this — they boot the factory image referenced in
`../../terraform/proxmox/images.tf`.

## Prerequisites

- `packer` >= 1.10 with the `hashicorp/proxmox` plugin (`packer init .`).
- A Debian netinst ISO uploaded to the node (see `iso_file` variable).
- A `http/preseed.cfg` answer file in this directory (referenced by
  `http_directory`/`boot_command`). Provide a standard Debian preseed that
  creates the `debian` user, installs `openssh-server`, and enables
  `cloud-init`. **Not committed** — it is environment-specific.

## Usage

```bash
packer init .
packer build \
  -var "pve_token_id=terraform@pve!tf" \
  -var "pve_token_secret=$PVE_TOKEN_SECRET" \
  debian-cloudinit.pkr.hcl
```

The resulting template (`vmid 9000`) is then cloned by Terraform `bpg/proxmox`
(`proxmox_virtual_environment_vm` with `clone { vm_id = 9000 }`) for utility VMs.
