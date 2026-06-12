# Ansible — UDM Pro network automation

Manages the inter-VLAN **firewall policies** the homelab needs on a UniFi Dream
Machine Pro, via the UniFi Network internal v2 API.

Your controller: **UniFi Network 10.4.57** → **Zone-Based Firewall (ZBF)**.
Policies reference *zones* (groups of networks), not raw subnets, and the zone
IDs are unique to your box — so the playbook discovers them first.

> **Scope:** this playbook only creates **firewall policies**. You create the
> VLAN networks (20 / 24 / 25) yourself in the UI first (Settings → Networks →
> New Virtual Network), and trunk them to the Proxmox port. VLAN creation is a
> one-time click; automating it via the fragile internal API isn't worth it.

## Why a local admin account, not an API key

You looked for **Settings → Control Plane → Integrations** and it wasn't there —
that's fine. The Integration API key (the `X-API-KEY` thing) only exposes
sites / devices / clients; it **cannot create firewall policies**. Firewall CRUD
lives on the *internal* v2 API, which authenticates with a normal login session.

So instead of hunting for an API key, create a **local admin account**:

1. Open the UniFi OS UI at `https://<udm-ip>` (e.g. `https://10.10.20.1`).
2. **Settings → Admins & Users → Add Admin**.
3. Choose **"Restrict to local access only"** (this creates a local username +
   password, independent of your Ubiquiti cloud SSO).
4. Give it **Full Management** (or at least Network admin) role.
5. Put the username/password in `group_vars/all.yml` (`udm_username`,
   `udm_password`), or pass the password at runtime with `-e`.

> If you *do* find an Integration API key later, it still won't help here — keep
> using the local admin for firewall automation.

## Usage

```bash
cd ansible
cp group_vars/all.example.yml group_vars/all.yml   # add your admin creds
# 1) DISCOVER (read-only): prints your firewall zones + existing policies
ansible-playbook -i inventory.ini udm-firewall.yml
# 2) copy the zone "_id" values into vars/firewall-rules.yml -> zone_ids
# 3) APPLY: create the missing policies
ansible-playbook -i inventory.ini udm-firewall.yml -e udm_apply=true
```

## ⚠️ Heads-up on the ZBF API

- The internal v2 API (`/proxy/network/v2/api/site/<site>/firewall-policies`) is
  **undocumented** and its JSON schema can change between releases. That's why
  discovery mode exists: confirm the exact field names/IDs on your 10.4.57 before
  trusting apply mode.
- If apply mode returns 400/404, paste me the discovery output and I'll match the
  request body to your controller's schema.
- Alternative: create the ~5 zone policies once by hand in the UI (they rarely
  change) and keep this playbook in discovery mode as a drift-check.

## Credentials hygiene

- `group_vars/all.yml` is git-ignored; prefer `ansible-vault encrypt` it.
- Use a dedicated local admin you can disable; don't reuse your personal login.
