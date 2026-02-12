# ============================================================
# OCI Terraform — Veteran Services Platform
# Root Module
# ============================================================
# Deploys the full OCI infrastructure equivalent of the AWS
# architecture: VCN, OKE, Autonomous DB, Redis, Object Storage,
# Load Balancer, DNS, WAF, Messaging, and AI Services.
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.30.0"
    }
  }

  # Uncomment and configure for remote state (recommended for teams)
  # backend "s3" {
  #   bucket                      = "terraform-state"
  #   key                         = "vetplatform/terraform.tfstate"
  #   region                      = "us-ashburn-1"
  #   endpoint                    = "https://<namespace>.compat.objectstorage.<region>.oraclecloud.com"
  #   shared_credentials_file     = "~/.oci/terraform-state-credentials"
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   force_path_style            = true
  # }
}

# ----------------------------------------------------------
# Provider Configuration
# ----------------------------------------------------------
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# ----------------------------------------------------------
# Data Sources
# ----------------------------------------------------------

# Get availability domains in the region
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Get latest Oracle Linux 8 image (for Nginx VM and OKE nodes)
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.nginx_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "display_name"
    values = ["^Oracle-Linux-8\\.\\d+-\\d{4}\\.\\d{2}\\.\\d{2}-\\d+$"]
    regex  = true
  }
}

# Get OCI services for Service Gateway
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

locals {
  prefix       = "${var.project_name}-${var.environment}"
  ad_names     = data.oci_identity_availability_domains.ads.availability_domains[*].name
  image_id     = var.nginx_image_ocid != "" ? var.nginx_image_ocid : data.oci_core_images.oracle_linux.images[0].id
  all_tags     = merge(var.freeform_tags, { "Environment" = var.environment })
  ocir_base    = "${var.region}.ocir.io/${var.ocir_namespace}"
}

# ----------------------------------------------------------
# Module: Networking
# ----------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  compartment_ocid          = var.compartment_ocid
  prefix                    = local.prefix
  vcn_cidr                  = var.vcn_cidr
  public_subnet_cidr        = var.public_subnet_cidr
  private_subnet_app_cidr   = var.private_subnet_app_cidr
  private_subnet_db_cidr    = var.private_subnet_db_cidr
  private_subnet_cache_cidr = var.private_subnet_cache_cidr
  oke_api_subnet_cidr       = var.oke_api_subnet_cidr
  oke_pod_subnet_cidr       = var.oke_pod_subnet_cidr
  all_services_id           = data.oci_core_services.all_services.services[0].id
  all_services_cidr         = data.oci_core_services.all_services.services[0].cidr_block
  freeform_tags             = local.all_tags
}

# ----------------------------------------------------------
# Module: Security (Vault)
# ----------------------------------------------------------
module "security" {
  source = "./modules/security"

  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  freeform_tags    = local.all_tags
}

# ----------------------------------------------------------
# Module: Object Storage
# ----------------------------------------------------------
module "storage" {
  source = "./modules/storage"

  compartment_ocid    = var.compartment_ocid
  prefix              = local.prefix
  bucket_name         = var.bucket_name
  bucket_storage_tier = var.bucket_storage_tier
  bucket_versioning   = var.bucket_versioning
  kms_key_id          = module.security.vault_key_id
  freeform_tags       = local.all_tags
}

# ----------------------------------------------------------
# Module: Autonomous Database
# ----------------------------------------------------------
module "database" {
  source = "./modules/database"

  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  subnet_id        = module.networking.private_subnet_db_id
  nsg_id           = module.networking.nsg_database_id
  admin_password   = var.adb_admin_password
  ecpu_count       = var.adb_ecpu_count
  storage_tb       = var.adb_storage_tb
  is_free_tier     = var.adb_is_free_tier
  freeform_tags    = local.all_tags
}

# ----------------------------------------------------------
# Module: OCI Cache with Redis
# ----------------------------------------------------------
module "cache" {
  source = "./modules/cache"

  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  subnet_id        = module.networking.private_subnet_cache_id
  nsg_id           = module.networking.nsg_cache_id
  node_count       = var.redis_node_count
  memory_gb        = var.redis_memory_gb
  freeform_tags    = local.all_tags
}

# ----------------------------------------------------------
# Module: Compute (Nginx VM)
# ----------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  compartment_ocid   = var.compartment_ocid
  prefix             = local.prefix
  availability_domain = local.ad_names[0]
  subnet_id          = module.networking.private_subnet_app_id
  nsg_id             = module.networking.nsg_app_id
  shape              = var.nginx_shape
  ocpus              = var.nginx_ocpus
  memory_gb          = var.nginx_memory_gb
  boot_volume_gb     = var.nginx_boot_volume_gb
  image_id           = local.image_id
  ssh_public_key     = file(var.ssh_public_key_path)
  freeform_tags      = local.all_tags
}

# ----------------------------------------------------------
# Module: OKE (Oracle Kubernetes Engine)
# ----------------------------------------------------------
module "oke" {
  source = "./modules/oke"

  compartment_ocid    = var.compartment_ocid
  tenancy_ocid        = var.tenancy_ocid
  prefix              = local.prefix
  vcn_id              = module.networking.vcn_id
  api_subnet_id       = module.networking.oke_api_subnet_id
  worker_subnet_id    = module.networking.private_subnet_app_id
  pod_subnet_id       = module.networking.oke_pod_subnet_id
  lb_subnet_id        = module.networking.public_subnet_id
  nsg_id              = module.networking.nsg_app_id
  kubernetes_version  = var.kubernetes_version
  node_shape          = var.oke_node_shape
  node_ocpus          = var.oke_node_ocpus
  node_memory_gb      = var.oke_node_memory_gb
  node_pool_size      = var.oke_node_pool_size
  node_boot_volume_gb = var.oke_node_boot_volume_gb
  image_id            = local.image_id
  ssh_public_key      = file(var.ssh_public_key_path)
  availability_domains = local.ad_names
  freeform_tags       = local.all_tags
}

# ----------------------------------------------------------
# Module: Load Balancer
# ----------------------------------------------------------
module "load_balancer" {
  source = "./modules/load-balancer"

  compartment_ocid      = var.compartment_ocid
  prefix                = local.prefix
  subnet_id             = module.networking.public_subnet_id
  nsg_id                = module.networking.nsg_lb_id
  shape                 = var.lb_shape
  min_bandwidth_mbps    = var.lb_min_bandwidth_mbps
  max_bandwidth_mbps    = var.lb_max_bandwidth_mbps
  nginx_private_ip      = module.compute.nginx_private_ip
  waf_enabled           = var.waf_enabled
  freeform_tags         = local.all_tags
}

# ----------------------------------------------------------
# Module: DNS
# ----------------------------------------------------------
module "dns" {
  source = "./modules/dns"

  compartment_ocid = var.compartment_ocid
  prefix           = local.prefix
  zone_name        = var.dns_zone_name
  app_hostname     = var.app_hostname
  lb_public_ip     = module.load_balancer.public_ip
  freeform_tags    = local.all_tags
}

# ----------------------------------------------------------
# Module: Messaging (Queue + Notifications)
# ----------------------------------------------------------
module "messaging" {
  source = "./modules/messaging"

  compartment_ocid        = var.compartment_ocid
  prefix                  = local.prefix
  notification_topic_name = var.notification_topic_name
  notification_email      = var.notification_email
  queue_name              = var.queue_name
  freeform_tags           = local.all_tags
}
