output "controlplane_ips" {
  description = "Control-plane node IPs (without CIDR mask)."
  value       = { for k, v in var.controlplanes : k => split("/", v.ip)[0] }
}

output "worker_ips" {
  description = "Worker node IPs (without CIDR mask)."
  value       = { for k, v in var.workers : k => split("/", v.ip)[0] }
}

output "lxc_ips" {
  description = "LXC IPs (without CIDR mask)."
  value       = { for k, v in var.lxcs : k => split("/", v.ip)[0] }
}
