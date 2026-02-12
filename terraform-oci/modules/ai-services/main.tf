# ============================================================
# Module: AI Services
# Replaces: AWS Textract + AWS Bedrock
# OCI Document Understanding + OCI Generative AI Service
# ============================================================
#
# NOTE: As of early 2025, OCI AI Services (Document Understanding
# and Generative AI) are consumed via API and do not require
# Terraform-provisioned infrastructure beyond IAM policies.
#
# This module creates the IAM policies needed for your OKE
# workloads to call these services.
# ============================================================

variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "prefix" { type = string }
variable "oke_dynamic_group_name" { type = string; default = "" }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# Dynamic Group for OKE pods to call AI services
# ----------------------------------------------------------
resource "oci_identity_dynamic_group" "oke_ai" {
  compartment_id = var.tenancy_ocid
  name           = "${var.prefix}-oke-ai-access"
  description    = "OKE pods that can access OCI AI Services"

  matching_rule = "ALL {resource.type = 'cluster', resource.compartment.id = '${var.compartment_ocid}'}"

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# IAM Policy — Document Understanding
# Replaces: AWS Textract
# Usage: OCR, table extraction, key-value pair extraction
# ----------------------------------------------------------
resource "oci_identity_policy" "doc_understanding" {
  compartment_id = var.compartment_ocid
  name           = "${var.prefix}-doc-understanding-policy"
  description    = "Allow OKE workloads to use OCI Document Understanding (replaces Textract)"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_ai.name} to use ai-service-document-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_ai.name} to read objectstorage-namespaces in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_ai.name} to read buckets in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_ai.name} to read objects in compartment id ${var.compartment_ocid}",
  ]

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# IAM Policy — Generative AI
# Replaces: AWS Bedrock
# Usage: LLM inference on extracted document data
# ----------------------------------------------------------
resource "oci_identity_policy" "generative_ai" {
  compartment_id = var.compartment_ocid
  name           = "${var.prefix}-generative-ai-policy"
  description    = "Allow OKE workloads to use OCI Generative AI (replaces Bedrock)"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_ai.name} to use generative-ai-family in compartment id ${var.compartment_ocid}",
  ]

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "ai_dynamic_group_id" { value = oci_identity_dynamic_group.oke_ai.id }

output "doc_understanding_api_info" {
  value = <<-INFO
    OCI Document Understanding API:
      Endpoint: https://document.aiservice.${replace(var.compartment_ocid, "/.*\\..*/", "")}oci.oraclecloud.com
      SDK: oci.ai_document.AIServiceDocumentClient
      Terraform-managed: IAM policies only (service is API-based)
      
    Features available (replaces Textract):
      - Text extraction (OCR)
      - Table extraction
      - Key-value pair extraction  
      - Document classification
  INFO
}

output "generative_ai_api_info" {
  value = <<-INFO
    OCI Generative AI API:
      Endpoint: https://inference.generativeai.<region>.oci.oraclecloud.com
      SDK: oci.generative_ai_inference.GenerativeAiInferenceClient
      Terraform-managed: IAM policies only (service is API-based)
      
    Models available (replaces Bedrock):
      - Cohere Command R/R+
      - Meta Llama 3.1
      - Dedicated AI Clusters (for high-throughput)
  INFO
}
