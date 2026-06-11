terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }

  # Local state by default. For team use, switch to a remote backend
  # (e.g. an S3-compatible MinIO bucket in the homelab) and keep state
  # out of git. State contains secrets (Talos PKI, tokens).
  # backend "s3" { ... }
}
