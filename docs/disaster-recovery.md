# Disaster recovery & off-site backup

This is the "the house burned down" playbook. It explains **what is backed up
where, how it stays private, and exactly how to rebuild** on a brand-new (but
identically specced) server — plus a routine to test the whole thing before you
actually need it.

---

## 1. How the backups work

### The chain
1. **Longhorn** runs the only stateful storage in the cluster. Every persistent
   volume (PostgreSQL, Pelican, future apps) lives on the **beta** SSD with one
   replica (single worker — see `kubernetes/platform/longhorn/longhorn-app.yaml`).
2. Volumes use the **encrypted default StorageClass** `longhorn-encrypted`
   (`longhorn-encrypted-storageclass.yaml`). Longhorn encrypts each volume with
   **LUKS** using the passphrase in the `longhorn-crypto` secret. Encryption sits
   **below** the backup layer, so everything Longhorn writes out is ciphertext.
3. A **RecurringJob** (`backup-recurringjob.yaml`, every 6h, keep 8) snapshots
   each volume and ships the backup to the **local MinIO** bucket
   `longhorn-backups` (`s3://longhorn-backups@us-east-1/`).
4. An **off-site CronJob** (`offsite-replication-cronjob.yaml`, every 3h) runs
   `mc mirror` to push that bucket to **your friend's MinIO**.

### Why your friend can't read your data
The objects Longhorn writes are already **LUKS-encrypted with your passphrase**.
Your friend owns/administers his MinIO and can see object names and sizes, but the
contents are ciphertext. Privacy does **not** depend on his MinIO access controls
— it depends on the `CRYPTO_KEY_VALUE` passphrase, which never leaves your control.

> **This means the `longhorn-crypto` passphrase IS your data.** Lose it and the
> off-site backups are permanently unreadable — by you too. Escrow it (see §3).

### Is the off-site backup reachable without a working home server?
**Yes.** The backup lives in your friend's MinIO, independent of your server. To
restore you don't need to do anything *at your friend's place* — you just need, from
anywhere with internet:
- his MinIO **endpoint + the access/secret key** he issued you, and
- your **`longhorn-crypto` passphrase**, and
- your **Talos/Proxmox secrets** (see §3).

Nothing has to be retrieved physically; a fresh cluster pulls the backups over the
network and decrypts them locally.

---

## 2. What you must keep off-site (escrow)

The cluster can be regenerated from this Git repo, but a handful of **secrets and
state files are git-ignored** and cannot be rebuilt from scratch. Back these up in
a password manager **and** offline (paper / encrypted USB in another location):

| Item | Where it lives | Why it's irreplaceable |
|------|----------------|------------------------|
| `longhorn-crypto` passphrase (`CRYPTO_KEY_VALUE`) | `longhorn-crypto-secret.yaml` | Decrypts every backup. No passphrase = no data, ever. |
| Friend's MinIO creds | `offsite-replication-secret.yaml` | How you reach the off-site copy. |
| Proxmox API token | `proxmox/terraform.tfvars` | Lets Terraform rebuild VMs/LXCs. (Re-issuable from Proxmox UI.) |
| **Talos secrets / PKI** | `infrastructure/terraform/talos/terraform.tfstate` | Cluster CA, etcd & machine certs. Losing it is fine for a *full rebuild* (you generate a new cluster), but keep it if you want to re-join the *same* cluster identity. |
| App secrets | `*-secret.yaml` (MinIO root, PG, Longhorn backup creds, Pelican) | Service logins; mostly re-settable, but easier to restore. |

> Talos state holds the cluster's secret material. For a **total-loss rebuild you
> generate a fresh cluster anyway**, so the old Talos state is optional — but the
> `longhorn-crypto` passphrase and the friend's MinIO creds are **mandatory**.

Recommended escrow: encrypt the whole bundle once (`gpg -c bundle.tar`) and store
the ciphertext somewhere durable + the GPG/password-manager key separately.

---

## 3. Full-loss rebuild on a new (identical) server

New R7 5800X / 64 GB box, same Proxmox node name `pve`, nothing else survives.

1. **Install Proxmox VE** on the new host; name the node `pve`; recreate the
   storage pools (`beta` SSD for VMs/LXCs; `local` for ISOs/snippets). Make
   `vmbr0` VLAN-aware. (Same prerequisites as a first install — see `guide.html`.)
2. **Clone this repo** on your workstation and restore the escrowed files:
   - `infrastructure/terraform/proxmox/terraform.tfvars`
   - each `kubernetes/**/[name]-secret.yaml` (especially **`longhorn-crypto-secret.yaml`**
     with the original passphrase, and `offsite-replication-secret.yaml`)
   - optionally the old `talos/terraform.tfstate` if re-joining the same identity.
3. **Re-issue the Proxmox API token** if needed and update `terraform.tfvars`.
4. **Provision + bootstrap** the cluster:
   ```sh
   cd infrastructure
   make all        # firewall -> VMs/LXCs -> Talos cluster -> Argo CD -> secrets
   ```
   Talos brings the VMs up as a working k8s cluster automatically; Argo CD then
   deploys everything in `kubernetes/`.
5. **Point Longhorn at the off-site data.** The local MinIO is empty on a fresh
   build, so temporarily set Longhorn's backup target to your friend's MinIO (or
   first `mc mirror` the friend's bucket back into the new local MinIO, then leave
   the target as the local bucket). Because `longhorn-crypto` holds the original
   passphrase, Longhorn can decrypt the backups.
6. **Restore volumes:** in the Longhorn UI (or via the API) → **Backup** → select
   each volume's latest backup → **Restore**, restoring into PVCs with the original
   names the apps expect (`postgresql`, Pelican, …). Argo CD reconciles the apps
   onto the restored data.
7. **Verify** each app comes up with its data, then switch the backup target back
   to the local bucket and let the off-site CronJob resume.

That's it — no action required at your friend's location beyond him keeping his
MinIO online and your scoped user valid.

---

## 4. Routine DR test (do this every month or two)

Don't wait for a real fire. Rehearse a *restore* in isolation:

1. **Restore-to-new-volume test (cheap, frequent):** In the Longhorn UI, restore
   the latest PostgreSQL backup to a **new** volume name (e.g. `pg-drtest`), mount
   it in a throwaway pod, and confirm the data is intact and decryptable. Delete
   the test volume afterwards. This proves the passphrase + off-site copy work.
2. **Off-site readability test:** From your workstation, with only the escrowed
   creds, run `mc ls offsite/<bucket>` to confirm the off-site copy is current and
   reachable independently of the cluster.
3. **Full rebuild drill (rare, thorough):** Once or twice a year, run §3 against a
   spare/nested Proxmox or a temporary VM cluster to confirm a from-zero rebuild
   still works end-to-end. Time it so you know your real RTO.
4. **Escrow check:** Confirm the `longhorn-crypto` passphrase in your password
   manager still matches the deployed secret (a restore is the real proof).

> Tip: a restore that *fails to decrypt* almost always means the `longhorn-crypto`
> passphrase doesn't match the one used when the backup was taken. Never rotate it
> without keeping the old value as long as old backups exist.

---

## 5. Quick reference

| You lose… | You need… | Recovery |
|-----------|-----------|----------|
| A pod / app | nothing special | Argo CD redeploys; data stays on Longhorn. |
| A volume (corruption) | local backup | Longhorn restore from `longhorn-backups`. |
| The whole server | escrowed secrets + off-site backup | Full rebuild, §3. |
| Home internet/site | off-site copy at friend's | Rebuild anywhere; pull from friend's MinIO. |
| The crypto passphrase | — | **Unrecoverable.** This is why §2 escrow is mandatory. |
