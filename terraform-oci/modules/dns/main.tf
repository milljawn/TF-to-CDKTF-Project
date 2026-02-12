# ============================================================
# Module: OCI DNS
# Replaces: AWS Route 53
# Role: Public DNS resolution for user traffic
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "zone_name" { type = string }
variable "app_hostname" { type = string }
variable "lb_public_ip" { type = string }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# DNS Zone
# ----------------------------------------------------------
resource "oci_dns_zone" "main" {
  compartment_id = var.compartment_ocid
  name           = var.zone_name
  zone_type      = "PRIMARY"
  freeform_tags  = var.freeform_tags
}

# ----------------------------------------------------------
# A Record — App hostname → Load Balancer IP
# ----------------------------------------------------------
resource "oci_dns_rrset" "app_a_record" {
  zone_name_or_id = oci_dns_zone.main.id
  domain          = "${var.app_hostname}.${var.zone_name}"
  rtype           = "A"
  compartment_id  = var.compartment_ocid

  items {
    domain = "${var.app_hostname}.${var.zone_name}"
    rtype  = "A"
    rdata  = var.lb_public_ip
    ttl    = 300
  }
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "zone_id" { value = oci_dns_zone.main.id }
output "zone_name_servers" { value = oci_dns_zone.main.nameservers }
output "app_fqdn" { value = "${var.app_hostname}.${var.zone_name}" }
