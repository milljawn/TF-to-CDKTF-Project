# ============================================================
# Module: Flexible Load Balancer + WAF
# Replaces: AWS Application Load Balancer
# Role: L7 routing, SSL termination, WAF protection
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "shape" { type = string }
variable "min_bandwidth_mbps" { type = number }
variable "max_bandwidth_mbps" { type = number }
variable "nginx_private_ip" { type = string }
variable "waf_enabled" { type = bool }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# Flexible Load Balancer
# ----------------------------------------------------------
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-lb"
  shape          = var.shape
  subnet_ids     = [var.subnet_id]

  network_security_group_ids = [var.nsg_id]
  is_private                 = false

  shape_details {
    minimum_bandwidth_in_mbps = var.min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.max_bandwidth_mbps
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Backend Set — Nginx
# ----------------------------------------------------------
resource "oci_load_balancer_backend_set" "nginx" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "${var.prefix}-bs-nginx"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = 80
    url_path          = "/health"
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
    return_code       = 200
  }
}

resource "oci_load_balancer_backend" "nginx" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.nginx.name
  ip_address       = var.nginx_private_ip
  port             = 80
}

# ----------------------------------------------------------
# Listener — HTTP (port 80)
# ----------------------------------------------------------
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "${var.prefix}-listener-http"
  default_backend_set_name = oci_load_balancer_backend_set.nginx.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = 300
  }
}

# NOTE: For HTTPS (port 443), you will need to:
# 1. Import or create an SSL certificate in OCI Certificates service
# 2. Add a certificate resource and HTTPS listener
# 3. Add an HTTP-to-HTTPS redirect rule set
# Example (uncomment and configure after adding certs):
#
# resource "oci_load_balancer_certificate" "ssl" {
#   load_balancer_id   = oci_load_balancer_load_balancer.main.id
#   certificate_name   = "${var.prefix}-ssl-cert"
#   public_certificate = file("path/to/cert.pem")
#   private_key        = file("path/to/key.pem")
#   ca_certificate     = file("path/to/ca-bundle.pem")
# }
#
# resource "oci_load_balancer_listener" "https" {
#   load_balancer_id         = oci_load_balancer_load_balancer.main.id
#   name                     = "${var.prefix}-listener-https"
#   default_backend_set_name = oci_load_balancer_backend_set.nginx.name
#   port                     = 443
#   protocol                 = "HTTP"
#   ssl_configuration {
#     certificate_name        = oci_load_balancer_certificate.ssl.certificate_name
#     verify_peer_certificate = false
#   }
# }

# ----------------------------------------------------------
# WAF Policy
# ----------------------------------------------------------
resource "oci_waf_web_app_firewall_policy" "main" {
  count          = var.waf_enabled ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-waf-policy"

  actions {
    name = "allowAction"
    type = "ALLOW"
  }

  actions {
    name = "return403"
    type = "RETURN_HTTP_RESPONSE"
    code = 403
    body {
      type = "STATIC_TEXT"
      text = "Access Denied"
    }
    headers {
      name  = "Content-Type"
      value = "text/plain"
    }
  }

  request_protection {
    rules {
      name        = "OWASP-CRS"
      type        = "PROTECTION"
      action_name = "return403"
      is_body_inspection_enabled = true

      protection_capabilities {
        key     = "920360"
        version = 1
      }

      protection_capabilities {
        key     = "941100"
        version = 1
      }
    }
  }

  freeform_tags = var.freeform_tags
}

resource "oci_waf_web_app_firewall" "main" {
  count                      = var.waf_enabled ? 1 : 0
  compartment_id             = var.compartment_ocid
  display_name               = "${var.prefix}-waf"
  backend_type               = "LOAD_BALANCER"
  load_balancer_id           = oci_load_balancer_load_balancer.main.id
  web_app_firewall_policy_id = oci_waf_web_app_firewall_policy.main[0].id
  freeform_tags              = var.freeform_tags
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "lb_id" { value = oci_load_balancer_load_balancer.main.id }

output "public_ip" {
  value = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}
