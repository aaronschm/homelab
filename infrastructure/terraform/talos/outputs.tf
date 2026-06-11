output "kubeconfig" {
  description = "Kubeconfig for the new cluster. Pipe to a file, do not commit."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl client configuration."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}
