# ============================================================
# Module: Autonomous Database
# Replaces: AWS RDS
# Stores: Case management, claim data, document metadata, profiles
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "admin_password" { type = string; sensitive = true }
variable "ecpu_count" { type = number }
variable "storage_tb" { type = number }
variable "is_free_tier" { type = bool }
variable "freeform_tags" { type = map(string) }

resource "oci_database_autonomous_database" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-adb"
  db_name        = replace(replace(var.prefix, "-", ""), "_", "")

  # Workload type: OLTP (Transaction Processing)
  db_workload                            = "OLTP"
  is_free_tier                           = var.is_free_tier
  compute_model                          = "ECPU"
  compute_count                          = var.ecpu_count
  data_storage_size_in_tbs               = var.storage_tb
  admin_password                         = var.admin_password
  is_auto_scaling_enabled                = true
  is_auto_scaling_for_storage_enabled    = true

  # Private endpoint (no public access)
  subnet_id          = var.subnet_id
  nsg_ids            = [var.nsg_id]
  is_mtls_connection_required = false

  # Backup retention
  backup_retention_period_in_days = 30

  # Security
  is_dedicated = false

  freeform_tags = var.freeform_tags

  lifecycle {
    ignore_changes = [admin_password]
  }
}

output "adb_id" { value = oci_database_autonomous_database.main.id }

output "connection_strings" {
  value     = oci_database_autonomous_database.main.connection_strings
  sensitive = true
}

output "private_endpoint" {
  value = oci_database_autonomous_database.main.private_endpoint
}
