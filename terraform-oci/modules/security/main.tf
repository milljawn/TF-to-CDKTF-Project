# ============================================================
# Module: Security
# OCI Vault (Key Management) + IAM policies
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# OCI Vault
# ----------------------------------------------------------
resource "oci_kms_vault" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-vault"
  vault_type     = "DEFAULT"
  freeform_tags  = var.freeform_tags
}

# ----------------------------------------------------------
# Master Encryption Key (AES-256)
# Used for: Object Storage encryption, ADB encryption, secrets
# ----------------------------------------------------------
resource "oci_kms_key" "master" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-master-key"
  management_endpoint = oci_kms_vault.main.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32 # 256-bit
  }

  protection_mode = "HSM"
  freeform_tags   = var.freeform_tags
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "vault_id" { value = oci_kms_vault.main.id }
output "vault_key_id" { value = oci_kms_key.master.id }
output "vault_management_endpoint" { value = oci_kms_vault.main.management_endpoint }
output "vault_crypto_endpoint" { value = oci_kms_vault.main.crypto_endpoint }
