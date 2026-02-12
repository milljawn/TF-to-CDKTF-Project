# TF-to-CDKTF-Project
Project For Things

# Veteran Services Platform — OCI CDKTF

CDKTF (TypeScript) translation of the `terraform-oci/` Terraform HCL project. Deploys the full Veteran Services Platform infrastructure on Oracle Cloud Infrastructure.

## Architecture

Identical to the original Terraform project — see `terraform-oci/docs/DEPLOYMENT_GUIDE.md` for the architecture diagram. All resources are replicated 1:1:

| CDKTF Construct | Terraform Module | OCI Service | Replaces (AWS) |
|---|---|---|---|
| `NetworkingConstruct` | `modules/networking` | VCN, Subnets, Gateways, NSGs | VPC |
| `SecurityConstruct` | `modules/security` | Vault, KMS Key | KMS |
| `StorageConstruct` | `modules/storage` | Object Storage + Lifecycle | S3 |
| `DatabaseConstruct` | `modules/database` | Autonomous Database (OLTP) | RDS |
| `CacheConstruct` | `modules/cache` | OCI Cache with Redis | ElastiCache |
| `ComputeConstruct` | `modules/compute` | Compute Instance (Nginx) | EC2 |
| `OkeConstruct` | `modules/oke` | OKE Enhanced Cluster + Node Pool | ECS Fargate |
| `LoadBalancerConstruct` | `modules/load-balancer` | Flexible LB + WAF | ALB + WAF |
| `DnsConstruct` | `modules/dns` | DNS Zone + A Record | Route 53 |
| `MessagingConstruct` | `modules/messaging` | Queue + Notifications + Events | SQS + SNS |
| `AiServicesConstruct` | `modules/ai-services` | IAM for Doc Understanding + GenAI | Textract + Bedrock |

## Prerequisites

- Node.js >= 18
- Terraform >= 1.5
- OCI CLI configured (`~/.oci/config`)
- SSH key pair at `~/.ssh/id_rsa.pub`

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Generate OCI provider bindings
npx cdktf get

# 3. Edit config.ts with your OCI credentials, or set env vars:
export OCI_TENANCY_OCID="ocid1.tenancy.oc1..aaaa..."
export OCI_USER_OCID="ocid1.user.oc1..aaaa..."
export OCI_COMPARTMENT_OCID="ocid1.compartment.oc1..aaaa..."
export OCI_FINGERPRINT="aa:bb:cc:..."
export OCI_PRIVATE_KEY_PATH="~/.oci/oci_api_key.pem"
export OCI_REGION="us-ashburn-1"
export OCI_OCIR_NAMESPACE="your_namespace"
export ADB_ADMIN_PASSWORD="YourStr0ng!Pass"

# 4. Synthesize (generates Terraform JSON)
npx cdktf synth

# 5. Review the plan
npx cdktf diff

# 6. Deploy
npx cdktf deploy

# 7. After deployment, apply K8s manifests
kubectl apply -f scripts/k8s-manifests.yaml
```

## Project Structure

```
├── main.ts                    # Stack entry point (mirrors main.tf)
├── config.ts                  # Configuration interface + defaults (mirrors variables.tf / tfvars)
├── constructs/                # One construct per Terraform module
│   ├── networking.ts
│   ├── security.ts
│   ├── storage.ts
│   ├── database.ts
│   ├── cache.ts
│   ├── compute.ts
│   ├── oke.ts
│   ├── load-balancer.ts
│   ├── dns.ts
│   ├── messaging.ts
│   └── ai-services.ts
├── cdktf.json                 # CDKTF provider config
├── tsconfig.json
├── package.json
└── scripts/
    └── k8s-manifests.yaml     # Kubernetes deployments (unchanged from original)
```

## Configuration

All configuration is centralized in `config.ts`. The `defaultConfig()` function provides defaults matching the original `terraform.tfvars.example`. Override values directly in `main.ts` or via environment variables.

## Customization

Each construct is a standalone reusable class. To customize, modify the construct config interfaces or extend the constructs. For example, to change the OKE node pool size:

```typescript
// In main.ts, override defaultConfig():
const cfg = defaultConfig();
cfg.okeNodePoolSize = 5;
new VetPlatformStack(app, "vetplatform-oci", cfg);
```

## Estimated Deployment Time

25–45 minutes (OKE and Autonomous DB take the longest), same as the Terraform HCL version.
