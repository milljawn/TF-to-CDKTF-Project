# ============================================================
# Module: Compute
# Nginx Web Server VM — Replaces: AWS EC2 (Nginx)
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "availability_domain" { type = string }
variable "subnet_id" { type = string }
variable "nsg_id" { type = string }
variable "shape" { type = string }
variable "ocpus" { type = number }
variable "memory_gb" { type = number }
variable "boot_volume_gb" { type = number }
variable "image_id" { type = string }
variable "ssh_public_key" { type = string }
variable "freeform_tags" { type = map(string) }

resource "oci_core_instance" "nginx" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  display_name        = "${var.prefix}-nginx"
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = [var.nsg_id]
    assign_public_ip = false
    display_name     = "${var.prefix}-nginx-vnic"
    hostname_label   = "nginx"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-CLOUD_INIT
      #!/bin/bash
      # Install and configure Nginx on Oracle Linux 8
      dnf install -y nginx
      systemctl enable nginx
      systemctl start nginx

      # Configure firewall
      firewall-cmd --permanent --add-service=http
      firewall-cmd --permanent --add-service=https
      firewall-cmd --reload

      # Create default upstream config placeholder
      cat > /etc/nginx/conf.d/upstream.conf << 'EOF'
      # Upstream configuration for OKE backend services
      # Update with OKE NodePort or ClusterIP service endpoints
      upstream oke_backend {
          # server <oke-worker-ip>:<nodeport>;
          server 127.0.0.1:8080;  # placeholder
      }

      server {
          listen 80;
          server_name _;

          location / {
              proxy_pass http://oke_backend;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # WebSocket support
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";
          }

          # Health check endpoint
          location /health {
              return 200 'OK';
              add_header Content-Type text/plain;
          }
      }
      EOF

      systemctl restart nginx
    CLOUD_INIT
    )
  }

  freeform_tags = var.freeform_tags
}

output "instance_id" { value = oci_core_instance.nginx.id }
output "nginx_private_ip" { value = oci_core_instance.nginx.private_ip }
