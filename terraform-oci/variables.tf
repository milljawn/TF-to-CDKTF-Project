# ============================================================
# OCI Terraform Variables — Veteran Services Platform
# ============================================================
# All variables the deploying engineer must provide.
# Copy terraform.tfvars.example → terraform.tfvars and fill in.
# ============================================================

# ----------------------------------------------------------
# OCI Provider / Authentication
# ----------------------------------------------------------
variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy. Found at: OCI Console → Profile → Tenancy → Copy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the deploying IAM user. Found at: OCI Console → Profile → My Profile → Copy OCID"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the target compartment. Found at: OCI Console → Identity → Compartments"
  type        = string
}

variable "region" {
  description = "OCI region for deployment (e.g., us-ashburn-1, us-phoenix-1)"
  type        = string
  default     = "us-ashburn-1"
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key. Found at: OCI Console → Profile → API Keys"
  type        = string
}

variable "private_key_path" {
  description = "Absolute path to the OCI API private key PEM file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

# ----------------------------------------------------------
# Project Metadata
# ----------------------------------------------------------
variable "project_name" {
  description = "Project identifier used as prefix for all resource names"
  type        = string
  default     = "vetplatform"
}

variable "environment" {
  description = "Deployment environment: dev, staging, prod"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "freeform_tags" {
  description = "Freeform tags applied to all resources"
  type        = map(string)
  default = {
    "Project"    = "VeteranServicesPlatform"
    "ManagedBy"  = "Terraform"
    "MigratedFrom" = "AWS"
  }
}

# ----------------------------------------------------------
# Networking
# ----------------------------------------------------------
variable "vcn_cidr" {
  description = "CIDR block for the Virtual Cloud Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet (Load Balancer, NAT GW, DNS)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_app_cidr" {
  description = "CIDR for private application subnet (OKE workers, Nginx VM)"
  type        = string
  default     = "10.0.10.0/24"
}

variable "private_subnet_db_cidr" {
  description = "CIDR for private database subnet (Autonomous DB)"
  type        = string
  default     = "10.0.20.0/24"
}

variable "private_subnet_cache_cidr" {
  description = "CIDR for private cache subnet (Redis)"
  type        = string
  default     = "10.0.30.0/24"
}

variable "oke_api_subnet_cidr" {
  description = "CIDR for OKE API endpoint subnet"
  type        = string
  default     = "10.0.5.0/24"
}

variable "oke_pod_subnet_cidr" {
  description = "CIDR for OKE pod networking (VCN-native)"
  type        = string
  default     = "10.0.128.0/17"
}

# ----------------------------------------------------------
# DNS
# ----------------------------------------------------------
variable "dns_zone_name" {
  description = "DNS zone name (e.g., example.com)"
  type        = string
  default     = "example.com"
}

variable "app_hostname" {
  description = "Hostname for the application (e.g., vetservices)"
  type        = string
  default     = "vetservices"
}

# ----------------------------------------------------------
# Compute — Nginx VM
# ----------------------------------------------------------
variable "nginx_shape" {
  description = "Compute shape for the Nginx web server VM"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "nginx_ocpus" {
  description = "Number of OCPUs for Nginx VM"
  type        = number
  default     = 2
}

variable "nginx_memory_gb" {
  description = "Memory in GB for Nginx VM"
  type        = number
  default     = 16
}

variable "nginx_boot_volume_gb" {
  description = "Boot volume size in GB for Nginx VM"
  type        = number
  default     = 50
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "nginx_image_ocid" {
  description = "OCID of the OS image for Nginx VM. Use Oracle Linux 8. Find at: OCI Console → Compute → Custom Images, or use platform images."
  type        = string
  default     = "" # Will be looked up via data source if blank
}

# ----------------------------------------------------------
# OKE — Oracle Kubernetes Engine
# ----------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes version for OKE cluster"
  type        = string
  default     = "v1.29.1"
}

variable "oke_node_shape" {
  description = "Compute shape for OKE worker nodes"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "oke_node_ocpus" {
  description = "OCPUs per OKE worker node"
  type        = number
  default     = 2
}

variable "oke_node_memory_gb" {
  description = "Memory in GB per OKE worker node"
  type        = number
  default     = 16
}

variable "oke_node_pool_size" {
  description = "Number of worker nodes in the OKE node pool"
  type        = number
  default     = 3
}

variable "oke_node_boot_volume_gb" {
  description = "Boot volume size in GB per OKE worker node"
  type        = number
  default     = 50
}

# ----------------------------------------------------------
# Container Images (OCIR)
# ----------------------------------------------------------
variable "ocir_namespace" {
  description = "OCI Object Storage namespace (used for OCIR). Run: oci os ns get"
  type        = string
}

variable "container_images" {
  description = "Map of container image URIs in OCIR"
  type        = map(string)
  default = {
    angular_frontend  = "vetplatform/angular-frontend:latest"
    node_backend      = "vetplatform/node-backend:latest"
    license_generator = "vetplatform/license-generator:latest"
    turbonumber       = "vetplatform/turbonumber:latest"
    docuseal          = "vetplatform/docuseal:latest"
    nginx             = "vetplatform/nginx:latest"
  }
}

# ----------------------------------------------------------
# Autonomous Database
# ----------------------------------------------------------
variable "adb_admin_password" {
  description = "Admin password for Autonomous Database. Requirements: 12-30 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char. No 'admin' in password."
  type        = string
  sensitive   = true
}

variable "adb_ecpu_count" {
  description = "Number of ECPUs for Autonomous Database"
  type        = number
  default     = 4
}

variable "adb_storage_tb" {
  description = "Storage size in TB for Autonomous Database"
  type        = number
  default     = 1
}

variable "adb_is_free_tier" {
  description = "Use Always Free Autonomous Database (for dev/test only)"
  type        = bool
  default     = false
}

# ----------------------------------------------------------
# OCI Cache with Redis
# ----------------------------------------------------------
variable "redis_node_count" {
  description = "Number of Redis nodes (1 for non-clustered, 3+ for clustered)"
  type        = number
  default     = 1
}

variable "redis_memory_gb" {
  description = "Memory in GB per Redis node"
  type        = number
  default     = 8
}

# ----------------------------------------------------------
# Object Storage
# ----------------------------------------------------------
variable "bucket_name" {
  description = "Name for the veteran documents Object Storage bucket"
  type        = string
  default     = "veteran-documents"
}

variable "bucket_storage_tier" {
  description = "Default storage tier: Standard or Archive"
  type        = string
  default     = "Standard"
}

variable "bucket_versioning" {
  description = "Enable object versioning on the bucket"
  type        = bool
  default     = true
}

# ----------------------------------------------------------
# Load Balancer
# ----------------------------------------------------------
variable "lb_shape" {
  description = "Load Balancer shape: flexible or fixed (10Mbps, 100Mbps, 400Mbps, 8000Mbps)"
  type        = string
  default     = "flexible"
}

variable "lb_min_bandwidth_mbps" {
  description = "Minimum bandwidth in Mbps (flexible shape)"
  type        = number
  default     = 10
}

variable "lb_max_bandwidth_mbps" {
  description = "Maximum bandwidth in Mbps (flexible shape)"
  type        = number
  default     = 100
}

# ----------------------------------------------------------
# Messaging
# ----------------------------------------------------------
variable "notification_topic_name" {
  description = "Name for the OCI Notifications topic (scanned doc alerts)"
  type        = string
  default     = "vetplatform-doc-alerts"
}

variable "notification_email" {
  description = "Email address for notification subscription (optional)"
  type        = string
  default     = ""
}

variable "queue_name" {
  description = "Name for the OCI Queue (user notification queue)"
  type        = string
  default     = "vetplatform-user-notifications"
}

# ----------------------------------------------------------
# WAF
# ----------------------------------------------------------
variable "waf_enabled" {
  description = "Enable OCI Web Application Firewall in front of the Load Balancer"
  type        = bool
  default     = true
}

# ----------------------------------------------------------
# External Integrations (informational — not Terraform-managed)
# ----------------------------------------------------------
variable "va_api_endpoint" {
  description = "VA REST API base URL for veteran data/documents (stored as config, not provisioned by Terraform)"
  type        = string
  default     = ""
}

variable "usps_api_endpoint" {
  description = "USPS.com Address Validation API endpoint (stored as config, not provisioned by Terraform)"
  type        = string
  default     = ""
}
