# ============================================================
# Module: OKE (Oracle Kubernetes Engine)
# Replaces: AWS ECS Fargate (6 containers)
# ============================================================

variable "compartment_ocid" { type = string }
variable "tenancy_ocid" { type = string }
variable "prefix" { type = string }
variable "vcn_id" { type = string }
variable "api_subnet_id" { type = string }
variable "worker_subnet_id" { type = string }
variable "pod_subnet_id" { type = string }
variable "lb_subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "kubernetes_version" { type = string }
variable "node_shape" { type = string }
variable "node_ocpus" { type = number }
variable "node_memory_gb" { type = number }
variable "node_pool_size" { type = number }
variable "node_boot_volume_gb" { type = number }
variable "image_id" { type = string }
variable "ssh_public_key" { type = string }
variable "availability_domains" { type = list(string) }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# OKE Cluster (Enhanced)
# ----------------------------------------------------------
resource "oci_containerengine_cluster" "main" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.prefix}-oke-cluster"
  vcn_id             = var.vcn_id
  type               = "ENHANCED_CLUSTER"

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = false
    subnet_id            = var.api_subnet_id
    nsg_ids              = [var.nsg_id]
  }

  options {
    service_lb_subnet_ids = [var.lb_subnet_id]

    kubernetes_network_config {
      services_cidr = "10.96.0.0/16"
      pods_cidr     = "10.244.0.0/16"
    }

    persistent_volume_config {
      freeform_tags = var.freeform_tags
    }
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# OKE Node Pool
# Runs: Angular FE, Node Backend, License Gen,
#       TurboNumber, Docuseal, Nginx Ingress
# ----------------------------------------------------------
resource "oci_containerengine_node_pool" "workers" {
  compartment_id     = var.compartment_ocid
  cluster_id         = oci_containerengine_cluster.main.id
  kubernetes_version = var.kubernetes_version
  name               = "${var.prefix}-node-pool"

  node_shape = var.node_shape

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gb
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = var.image_id
    boot_volume_size_in_gbs = var.node_boot_volume_gb
  }

  node_config_details {
    size = var.node_pool_size

    dynamic "placement_configs" {
      for_each = var.availability_domains
      content {
        availability_domain = placement_configs.value
        subnet_id           = var.worker_subnet_id
      }
    }

    nsg_ids       = [var.nsg_id]
    freeform_tags = var.freeform_tags
  }

  node_pool_pod_network_option_details {
    cni_type       = "OCI_VCN_IP_NATIVE"
    pod_subnet_ids = [var.pod_subnet_id]
    pod_nsg_ids    = [var.nsg_id]
  }

  ssh_public_key = var.ssh_public_key

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "cluster_id" {
  value = oci_containerengine_cluster.main.id
}

output "cluster_endpoint" {
  value = oci_containerengine_cluster.main.endpoints[0].kubernetes
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.workers.id
}
