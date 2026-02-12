# ============================================================
# Module: Networking
# VCN, Subnets, Gateways, Route Tables, Security Lists, NSGs
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "vcn_cidr" { type = string }
variable "public_subnet_cidr" { type = string }
variable "private_subnet_app_cidr" { type = string }
variable "private_subnet_db_cidr" { type = string }
variable "private_subnet_cache_cidr" { type = string }
variable "oke_api_subnet_cidr" { type = string }
variable "oke_pod_subnet_cidr" { type = string }
variable "all_services_id" { type = string }
variable "all_services_cidr" { type = string }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# VCN
# ----------------------------------------------------------
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.prefix}-vcn"
  dns_label      = replace(var.prefix, "-", "")
  freeform_tags  = var.freeform_tags
}

# ----------------------------------------------------------
# Gateways
# ----------------------------------------------------------
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-igw"
  enabled        = true
  freeform_tags  = var.freeform_tags
}

resource "oci_core_nat_gateway" "natgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-natgw"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_service_gateway" "svcgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-svcgw"

  services {
    service_id = var.all_services_id
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Route Tables
# ----------------------------------------------------------
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-rt-public"

  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    description       = "Internet access via IGW"
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-rt-private"

  route_rules {
    network_entity_id = oci_core_nat_gateway.natgw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    description       = "Outbound internet via NAT Gateway"
  }

  route_rules {
    network_entity_id = oci_core_service_gateway.svcgw.id
    destination       = var.all_services_cidr
    destination_type  = "SERVICE_CIDR_BLOCK"
    description       = "OCI services via Service Gateway"
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Security Lists
# ----------------------------------------------------------
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-sl-public"

  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    description = "HTTPS from internet"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    description = "HTTP from internet (redirect to HTTPS)"
    tcp_options {
      min = 80
      max = 80
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound"
  }

  freeform_tags = var.freeform_tags
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-sl-private"

  ingress_security_rules {
    protocol    = "6"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    description = "All TCP within VCN"
  }

  ingress_security_rules {
    protocol    = "1" # ICMP
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    description = "ICMP within VCN"
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound"
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Subnets
# ----------------------------------------------------------
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.prefix}-subnet-public"
  dns_label                  = "pub"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "private_app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_app_cidr
  display_name               = "${var.prefix}-subnet-app"
  dns_label                  = "app"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "private_db" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_db_cidr
  display_name               = "${var.prefix}-subnet-db"
  dns_label                  = "db"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "private_cache" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.private_subnet_cache_cidr
  display_name               = "${var.prefix}-subnet-cache"
  dns_label                  = "cache"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "oke_api" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.oke_api_subnet_cidr
  display_name               = "${var.prefix}-subnet-oke-api"
  dns_label                  = "okeapi"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "oke_pods" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = var.oke_pod_subnet_cidr
  display_name               = "${var.prefix}-subnet-oke-pods"
  dns_label                  = "okepods"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
}

# ----------------------------------------------------------
# Network Security Groups (NSGs)
# ----------------------------------------------------------
resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-nsg-lb"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_https" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTPS from internet"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_http" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTP from internet"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress_app" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_app_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "LB to app subnet"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-nsg-app"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_network_security_group_security_rule" "app_from_lb" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.lb.id
  source_type               = "NETWORK_SECURITY_GROUP"
  description               = "HTTP from Load Balancer"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "app_internal" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.private_subnet_app_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Internal app-to-app (OKE pods, GraphQL, etc.)"
}

resource "oci_core_network_security_group_security_rule" "app_egress_all" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  description               = "Allow all outbound from app"
}

resource "oci_core_network_security_group" "database" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-nsg-database"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_network_security_group_security_rule" "db_from_app" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.app.id
  source_type               = "NETWORK_SECURITY_GROUP"
  description               = "Oracle SQL*Net from app tier"
  tcp_options {
    destination_port_range {
      min = 1522
      max = 1522
    }
  }
}

resource "oci_core_network_security_group_security_rule" "db_egress" {
  network_security_group_id = oci_core_network_security_group.database.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_app_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "Response to app tier"
}

resource "oci_core_network_security_group" "cache" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-nsg-cache"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_network_security_group_security_rule" "cache_from_app" {
  network_security_group_id = oci_core_network_security_group.cache.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.app.id
  source_type               = "NETWORK_SECURITY_GROUP"
  description               = "Redis from app tier"
  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cache_egress" {
  network_security_group_id = oci_core_network_security_group.cache.id
  direction                 = "EGRESS"
  protocol                  = "6"
  destination               = var.private_subnet_app_cidr
  destination_type          = "CIDR_BLOCK"
  description               = "Response to app tier"
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "vcn_id" { value = oci_core_vcn.main.id }
output "public_subnet_id" { value = oci_core_subnet.public.id }
output "private_subnet_app_id" { value = oci_core_subnet.private_app.id }
output "private_subnet_db_id" { value = oci_core_subnet.private_db.id }
output "private_subnet_cache_id" { value = oci_core_subnet.private_cache.id }
output "oke_api_subnet_id" { value = oci_core_subnet.oke_api.id }
output "oke_pod_subnet_id" { value = oci_core_subnet.oke_pods.id }
output "nsg_lb_id" { value = oci_core_network_security_group.lb.id }
output "nsg_app_id" { value = oci_core_network_security_group.app.id }
output "nsg_database_id" { value = oci_core_network_security_group.database.id }
output "nsg_cache_id" { value = oci_core_network_security_group.cache.id }
