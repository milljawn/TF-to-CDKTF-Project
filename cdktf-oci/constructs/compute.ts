// ============================================================
// Construct: Compute
// Nginx Web Server VM — Replaces: AWS EC2 (Nginx)
// Mirrors: modules/compute/main.tf
// ============================================================

import { Construct } from "constructs";
import { CoreInstance } from "../.gen/providers/oci/core-instance";

export interface ComputeConfig {
  compartmentOcid: string;
  prefix: string;
  availabilityDomain: string;
  subnetId: string;
  nsgId: string;
  shape: string;
  ocpus: number;
  memoryGb: number;
  bootVolumeGb: number;
  imageId: string;
  sshPublicKey: string;
  freeformTags: { [key: string]: string };
}

export class ComputeConstruct extends Construct {
  public readonly nginx: CoreInstance;

  constructor(scope: Construct, id: string, config: ComputeConfig) {
    super(scope, id);

    const cloudInit = `#!/bin/bash
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

systemctl restart nginx`;

    this.nginx = new CoreInstance(this, "nginx", {
      compartmentId: config.compartmentOcid,
      availabilityDomain: config.availabilityDomain,
      displayName: `${config.prefix}-nginx`,
      shape: config.shape,
      shapeConfig: {
        ocpus: config.ocpus,
        memoryInGbs: config.memoryGb,
      },
      sourceDetails: {
        sourceType: "image",
        sourceId: config.imageId,
        bootVolumeSizeInGbs: String(config.bootVolumeGb),
      },
      createVnicDetails: {
        subnetId: config.subnetId,
        nsgIds: [config.nsgId],
        assignPublicIp: "false",
        displayName: `${config.prefix}-nginx-vnic`,
        hostnameLabel: "nginx",
      },
      metadata: {
        ssh_authorized_keys: config.sshPublicKey,
        user_data: Buffer.from(cloudInit).toString("base64"),
      },
      freeformTags: config.freeformTags,
    });
  }
}
