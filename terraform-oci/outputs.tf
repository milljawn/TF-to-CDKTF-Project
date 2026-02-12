# ============================================================
# Root Outputs — Veteran Services Platform
# ============================================================

# ----------------------------------------------------------
# Networking
# ----------------------------------------------------------
output "vcn_id" {
  description = "OCID of the VCN"
  value       = module.networking.vcn_id
}

output "vcn_cidr" {
  description = "VCN CIDR block"
  value       = var.vcn_cidr
}

# ----------------------------------------------------------
# OKE
# ----------------------------------------------------------
output "oke_cluster_id" {
  description = "OCID of the OKE cluster"
  value       = module.oke.cluster_id
}

output "oke_cluster_endpoint" {
  description = "OKE Kubernetes API endpoint"
  value       = module.oke.cluster_endpoint
}

output "oke_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file ~/.kube/config --region ${var.region} --token-version 2.0.0"
}

output "oke_node_pool_id" {
  description = "OCID of the OKE node pool"
  value       = module.oke.node_pool_id
}

# ----------------------------------------------------------
# Compute
# ----------------------------------------------------------
output "nginx_instance_id" {
  description = "OCID of the Nginx compute instance"
  value       = module.compute.instance_id
}

output "nginx_private_ip" {
  description = "Private IP of the Nginx VM"
  value       = module.compute.nginx_private_ip
}

# ----------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------
output "lb_id" {
  description = "OCID of the Flexible Load Balancer"
  value       = module.load_balancer.lb_id
}

output "lb_public_ip" {
  description = "Public IP address of the Load Balancer"
  value       = module.load_balancer.public_ip
}

# ----------------------------------------------------------
# DNS
# ----------------------------------------------------------
output "app_url" {
  description = "Full application URL"
  value       = "https://${var.app_hostname}.${var.dns_zone_name}"
}

output "dns_zone_id" {
  description = "OCID of the DNS zone"
  value       = module.dns.zone_id
}

# ----------------------------------------------------------
# Database
# ----------------------------------------------------------
output "adb_id" {
  description = "OCID of the Autonomous Database"
  value       = module.database.adb_id
}

output "adb_connection_strings" {
  description = "Autonomous Database connection strings"
  value       = module.database.connection_strings
  sensitive   = true
}

output "adb_private_endpoint" {
  description = "Autonomous Database private endpoint"
  value       = module.database.private_endpoint
}

# ----------------------------------------------------------
# Cache
# ----------------------------------------------------------
output "redis_id" {
  description = "OCID of the OCI Cache (Redis) cluster"
  value       = module.cache.redis_id
}

output "redis_endpoint" {
  description = "Redis primary endpoint hostname"
  value       = module.cache.redis_endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.cache.redis_port
}

# ----------------------------------------------------------
# Storage
# ----------------------------------------------------------
output "bucket_name" {
  description = "Name of the Object Storage bucket"
  value       = module.storage.bucket_name
}

output "bucket_namespace" {
  description = "Object Storage namespace"
  value       = module.storage.bucket_namespace
}

# ----------------------------------------------------------
# Messaging
# ----------------------------------------------------------
output "notification_topic_id" {
  description = "OCID of the Notifications topic"
  value       = module.messaging.topic_id
}

output "queue_id" {
  description = "OCID of the OCI Queue"
  value       = module.messaging.queue_id
}

output "queue_endpoint" {
  description = "OCI Queue endpoint URL"
  value       = module.messaging.queue_endpoint
}

# ----------------------------------------------------------
# Security
# ----------------------------------------------------------
output "vault_id" {
  description = "OCID of the OCI Vault"
  value       = module.security.vault_id
}

# ----------------------------------------------------------
# Container Registry
# ----------------------------------------------------------
output "ocir_login_command" {
  description = "Docker login command for OCIR"
  value       = "docker login ${var.region}.ocir.io"
}

output "ocir_image_prefix" {
  description = "Base URI for OCIR images"
  value       = "${var.region}.ocir.io/${var.ocir_namespace}"
}
