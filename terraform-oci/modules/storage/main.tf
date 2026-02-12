# ============================================================
# Module: Object Storage
# Replaces: AWS S3
# Role: Veteran document storage (upload/fetch)
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "bucket_name" { type = string }
variable "bucket_storage_tier" { type = string }
variable "bucket_versioning" { type = bool }
variable "kms_key_id" { type = string }
variable "freeform_tags" { type = map(string) }

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "veteran_docs" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "${var.prefix}-${var.bucket_name}"
  access_type    = "NoPublicAccess"
  storage_tier   = var.bucket_storage_tier
  versioning     = var.bucket_versioning ? "Enabled" : "Disabled"
  kms_key_id     = var.kms_key_id

  # Enable object events for notification triggers
  object_events_enabled = true

  freeform_tags = var.freeform_tags
}

# Lifecycle policy to transition old documents to Infrequent Access
resource "oci_objectstorage_object_lifecycle_policy" "lifecycle" {
  namespace  = data.oci_objectstorage_namespace.ns.namespace
  bucket     = oci_objectstorage_bucket.veteran_docs.name

  rules {
    name        = "archive-old-docs"
    action      = "INFREQUENT_ACCESS"
    time_amount = 90
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }

  rules {
    name        = "archive-very-old-docs"
    action      = "ARCHIVE"
    time_amount = 365
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }
}

output "bucket_name" { value = oci_objectstorage_bucket.veteran_docs.name }
output "bucket_namespace" { value = data.oci_objectstorage_namespace.ns.namespace }
output "bucket_id" { value = oci_objectstorage_bucket.veteran_docs.id }
