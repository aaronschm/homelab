# Ansible — UDM Pro network automation

Manages the inter-VLAN **firewall policies** the homelab needs on a UniFi Dream
Machine Pro, via the UniFi Network internal v2 API.

Your controller: **UniFi Network 10.x** → **Zone-Based Firewall (ZBF)**.
Zone IDs are resolved **automatically** from zone names — no manual hex-string
copying needed.

> **Scope:** this playbook only creates **firewall policies**. You create the
> VLAN networks (10 / 20 / 24 / 25) yourself in the UI first (Settings →
> Networks → New Virtual Network), and trunk them to the Proxmox port.

## Why a local admin account, not an API key

The Integration API key (`X-API-KEY`) only exposes sites / devices / clients; it
**cannot create firewall policies**. Firewall CRUD lives on the *internal* v2
API, which authenticates with a normal login session.

Create a **local admin account**:

1. Open the UniFi OS UI at `https://<udm-ip>` (e.g. `https://10.10.20.1`).
2. **Settings → Admins & Users → Add Admin**.
3. Choose **"Restrict to local access only"** (local username + password,
   independent of your Ubiquiti cloud SSO).
4. Give it **Full Management** (or at least Network admin) role.
5. Put the username/password in `group_vars/all.yml` (`udm_username`,
   `udm_password`), or pass the password at runtime with `-e`.

## Usage

```bash
cd ansible
cp group_vars/all.example.yml group_vars/all.yml   # add your admin creds

# Dry run (read-only): shows resolved zone names → IDs + existing policy names
ansible-playbook -i inventory.ini udm-firewall.yml

# Apply: create any missing policies
ansible-playbook -i inventory.ini udm-firewall.yml -e udm_apply=true
```

Zone names in `vars/firewall-rules.yml` must **exactly match** (case-sensitive)
the zone names shown in your UniFi UI (Settings → Zones). If a name doesn't
match, the playbook fails with the list of available zones.

## ⚠️ Heads-up on the ZBF API

- The internal v2 API (`/proxy/network/v2/api/site/<site>/firewall-policies`) is
  **undocumented** and its JSON schema can change between releases.
- If apply mode returns 400/404, paste the error and I'll match the request body
  to your controller's schema.

## Credentials hygiene

- `group_vars/all.yml` is git-ignored; prefer `ansible-vault encrypt` it.
- Use a dedicated local admin you can disable; don't reuse your personal login.
