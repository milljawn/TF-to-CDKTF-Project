# ============================================================
# Module: OCI Cache with Redis
# Replaces: AWS ElastiCache for Redis
# Role: WebSocket brokering, HTTP request queuing, license caching
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "node_count" { type = number }
variable "memory_gb" { type = number }
variable "freeform_tags" { type = map(string) }

resource "oci_redis_redis_cluster" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-redis"
  subnet_id      = var.subnet_id
  nsg_ids        = [var.nsg_id]

  node_count          = var.node_count
  node_memory_in_gbs  = var.memory_gb
  software_version    = "REDIS_7_0"

  freeform_tags = var.freeform_tags
}

output "redis_id" { value = oci_redis_redis_cluster.main.id }

output "redis_endpoint" {
  value = oci_redis_redis_cluster.main.primary_endpoint_ip_address
}

output "redis_port" {
  value = 6379
}
