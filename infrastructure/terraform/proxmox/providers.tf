provider "proxmox" {
  endpoint = var.pve_endpoint
  insecure = var.pve_insecure

  # Prefer an API token over a password. Create a least-privilege role/token
  # in Proxmox (Datacenter > Permissions > API Tokens). Format:
  #   "USER@REALM!TOKENID=UUID"
  api_token = var.pve_api_token

  # Required so the provider can upload cloud-init snippets and import disk
  # images over SSH to the node. Uses the SSH agent by default.
  ssh {
    agent    = true
    username = var.pve_ssh_username
    private_key = file(var.pve_ssh_private_key_file)
  }
}
