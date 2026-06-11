# Ansible — UDM Pro network automation

Manages the inter-VLAN firewall the homelab bootstrap needs on a UniFi Dream
Machine Pro, via the UniFi Network API, using an **API key**.

Your controller: **UniFi Network 10.4.57** → **Zone-Based Firewall (ZBF)**.
Policies reference *zones* (groups of networks), not raw subnets, and the zone
IDs are unique to your box — so the playbook discovers them first.

## How to create the API key

1. Open the UniFi Network app (`https://<udm-ip>` or `https://unifi.ui.com`).
2. Go to **Settings → Control Plane → Integrations** (newer builds:
   **Settings → System → API**). 
3. Click **Create API Key**, name it `ansible`, copy the key (shown once).
4. Put it in `group_vars/all.yml` as `udm_api_key`, or pass at runtime:
   `-e "udm_api_key=$UDM_API_KEY"`.

The key is sent as the `X-API-KEY` header. No username/password needed.

## Usage

```bash
cd ansible
cp group_vars/all.example.yml group_vars/all.yml   # add your API key
# 1) DISCOVER (read-only): prints your firewall zones + existing policies
ansible-playbook -i inventory.ini udm-firewall.yml
# 2) copy the zone "_id" values into vars/firewall-rules.yml -> zone_ids
# 3) APPLY: create the missing policies
ansible-playbook -i inventory.ini udm-firewall.yml -e udm_apply=true
```

## ⚠️ Heads-up on the ZBF API

- The official **Integration API** (`/proxy/network/integration/v1/...`) is what
  the API key is blessed for, but it currently exposes sites/devices/clients —
  **not** firewall policy CRUD.
- Firewall policies live on the **internal v2 API**
  (`/proxy/network/v2/api/site/<site>/firewall-policies`). The API key works
  against it on current firmware, but the JSON schema is **undocumented and can
  change between releases**. That's why discovery mode exists: confirm the exact
  field names/IDs from your 10.4.57 before trusting apply mode.
- If apply mode returns 400/404, paste me the discovery output and I'll match the
  body to your controller's schema.

Alternative if you'd rather not touch the internal API: create the ~5 zone
policies once by hand in the UI (they rarely change), and keep this playbook in
discovery mode as documentation/drift-check.

## Credentials hygiene

- `group_vars/all.yml` is git-ignored; prefer `ansible-vault encrypt` it.
- Use a dedicated API key you can revoke; don't reuse your login.
