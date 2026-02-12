# OCI Terraform Deployment Guide
## Veteran Services Platform — AWS to OCI Migration

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Required Information Checklist](#2-required-information-checklist)
3. [OCI Authentication Setup](#3-oci-authentication-setup)
4. [Configuring terraform.tfvars](#4-configuring-terraformtfvars)
5. [Container Image Preparation](#5-container-image-preparation)
6. [Deployment Steps](#6-deployment-steps)
7. [Post-Deployment Validation](#7-post-deployment-validation)
8. [Architecture Reference](#8-architecture-reference)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

### Tools Required

| Tool | Minimum Version | Install Command |
|------|----------------|-----------------|
| Terraform | >= 1.5.0 | `brew install terraform` or [terraform.io](https://developer.hashicorp.com/terraform/downloads) |
| OCI CLI | >= 3.37.0 | `brew install oci-cli` or `pip install oci-cli` |
| kubectl | >= 1.28 | `brew install kubectl` |
| Docker | >= 24.0 | [docker.com](https://docs.docker.com/get-docker/) |
| Helm | >= 3.12 | `brew install helm` |

### OCI Account Requirements

- [ ] Active OCI tenancy with Universal Credits or Pay-As-You-Go
- [ ] IAM user with Administrator privileges (or equivalent policies)
- [ ] Home region identified (e.g., `us-ashburn-1`, `us-phoenix-1`)
- [ ] Compartment created for this project
- [ ] Service limits verified (see Section 2)

### Service Limit Verification

Run these OCI CLI commands to verify your tenancy has capacity:

```bash
# Check compute limits
oci limits value list --service-name compute --compartment-id <tenancy_ocid> \
  --query "data[?name=='standard-e4-core-count']"

# Check OKE cluster limit
oci limits value list --service-name cluster --compartment-id <tenancy_ocid> \
  --query "data[?name=='cluster-count']"

# Check Autonomous DB limits
oci limits value list --service-name database --compartment-id <tenancy_ocid> \
  --query "data[?name=='adb-free-count']"

# Check load balancer limits
oci limits value list --service-name load-balancer --compartment-id <tenancy_ocid>
```

---

## 2. Required Information Checklist

### ⚠️ CRITICAL — Gather ALL of these before running Terraform

#### OCI Identity & Tenancy

| Parameter | Where to Find | Your Value |
|-----------|--------------|------------|
| **Tenancy OCID** | OCI Console → Profile → Tenancy: `<tenancy_name>` → Copy OCID | `ocid1.tenancy.oc1..aaaa...` |
| **User OCID** | OCI Console → Profile → My Profile → Copy OCID | `ocid1.user.oc1..aaaa...` |
| **Compartment OCID** | OCI Console → Identity → Compartments → Select → Copy OCID | `ocid1.compartment.oc1..aaaa...` |
| **Home Region** | OCI Console → Administration → Tenancy Details → Home Region | e.g., `us-ashburn-1` |
| **Deployment Region** | Choose deployment region (can differ from home) | e.g., `us-ashburn-1` |

#### API Key Authentication

| Parameter | Where to Find | Your Value |
|-----------|--------------|------------|
| **API Key Fingerprint** | OCI Console → Profile → API Keys → Fingerprint column | `aa:bb:cc:dd:...` |
| **API Private Key Path** | Local path to the PEM private key file | `/path/to/oci_api_key.pem` |

#### Networking

| Parameter | Recommended Default | Your Value |
|-----------|-------------------|------------|
| **VCN CIDR** | `10.0.0.0/16` | |
| **Public Subnet CIDR** | `10.0.1.0/24` | |
| **Private Subnet CIDR (App)** | `10.0.10.0/24` | |
| **Private Subnet CIDR (DB)** | `10.0.20.0/24` | |
| **Private Subnet CIDR (Cache)** | `10.0.30.0/24` | |
| **OKE API Subnet CIDR** | `10.0.5.0/24` | |
| **OKE Pod Subnet CIDR** | `10.0.128.0/17` | |

#### DNS & Domain

| Parameter | Description | Your Value |
|-----------|-------------|------------|
| **Domain Name** | Public domain for the application | e.g., `vetservices.example.com` |
| **DNS Zone Name** | Parent DNS zone | e.g., `example.com` |

#### Database

| Parameter | Recommended Default | Your Value |
|-----------|-------------------|------------|
| **ADB Admin Password** | Must be 12-30 chars, 1 upper, 1 lower, 1 number, 1 special | |
| **ADB ECPU Count** | `4` | |
| **ADB Storage (TB)** | `1` | |
| **ADB Workload Type** | `OLTP` (Transaction Processing) | |

#### Container Images

| Container | AWS Source | OCI Registry Target |
|-----------|-----------|---------------------|
| **Angular Frontend** | Current ECR URI | `<region>.ocir.io/<namespace>/vetplatform/angular-frontend:latest` |
| **Node Backend** | Current ECR URI | `<region>.ocir.io/<namespace>/vetplatform/node-backend:latest` |
| **License Generator** | Current ECR URI | `<region>.ocir.io/<namespace>/vetplatform/license-generator:latest` |
| **TurboNumber** | Current ECR URI | `<region>.ocir.io/<namespace>/vetplatform/turbonumber:latest` |
| **Docuseal** | Current ECR URI | `<region>.ocir.io/<namespace>/vetplatform/docuseal:latest` |
| **Nginx** | Current ECR URI or `nginx:latest` | `<region>.ocir.io/<namespace>/vetplatform/nginx:latest` |

#### External Integration Endpoints

| Service | Current AWS Endpoint | Notes |
|---------|---------------------|-------|
| **VA REST API** | | Base URL for veteran data/documents |
| **USPS Address Validation** | | API key + endpoint |

#### SSH Access

| Parameter | Description | Your Value |
|-----------|-------------|------------|
| **SSH Public Key** | For Nginx VM and OKE worker node access | Path to `~/.ssh/id_rsa.pub` |

---

## 3. OCI Authentication Setup

### Option A: API Key Authentication (Recommended for Terraform)

```bash
# 1. Generate an API signing key pair
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

# 2. Upload the PUBLIC key to OCI
#    OCI Console → Profile → API Keys → Add API Key → Paste Public Key

# 3. Copy the fingerprint shown after upload

# 4. Configure OCI CLI
oci setup config
# Follow prompts — enter: User OCID, Tenancy OCID, Region, Key path

# 5. Verify connectivity
oci iam region list --output table
```

### Option B: Instance Principal (For CI/CD pipelines on OCI)

If running Terraform from an OCI Compute instance, set `auth = "InstancePrincipal"` in the provider block and create a dynamic group + policy:

```hcl
# Dynamic group matching your CI/CD instance
resource "oci_identity_dynamic_group" "terraform_runner" {
  compartment_id = var.tenancy_ocid
  name           = "TerraformRunners"
  matching_rule  = "instance.compartment.id = '${var.compartment_ocid}'"
}

# Policy granting permissions
resource "oci_identity_policy" "terraform_policy" {
  compartment_id = var.tenancy_ocid
  name           = "TerraformDeployPolicy"
  statements = [
    "Allow dynamic-group TerraformRunners to manage all-resources in compartment id ${var.compartment_ocid}"
  ]
}
```

---

## 4. Configuring terraform.tfvars

After gathering all values from Section 2, copy `terraform.tfvars.example` to `terraform.tfvars` and fill in every value:

```bash
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars  # Edit with your values
```

**IMPORTANT:** Never commit `terraform.tfvars` to version control — it contains secrets.

Add to `.gitignore`:
```
terraform.tfvars
*.pem
.terraform/
*.tfstate*
```

---

## 5. Container Image Preparation

### Push Images to OCI Container Registry (OCIR)

```bash
# 1. Get your OCI object storage namespace
oci os ns get --query 'data' --raw-output
# Returns something like: "axaxnpcrorhs"

# 2. Create OCIR repositories (one per container)
NAMESPACE=$(oci os ns get --query 'data' --raw-output)
REGION="us-ashburn-1"  # your region

for repo in angular-frontend node-backend license-generator turbonumber docuseal nginx; do
  oci artifacts container repository create \
    --compartment-id <compartment_ocid> \
    --display-name "vetplatform/${repo}" \
    --is-public false
done

# 3. Docker login to OCIR
docker login ${REGION}.ocir.io \
  --username "${NAMESPACE}/your.email@example.com" \
  --password "<your_auth_token>"
# Generate auth token: OCI Console → Profile → Auth Tokens → Generate Token

# 4. Pull from AWS ECR, tag for OCIR, push
# Repeat for each container:
docker pull <aws_ecr_uri>/angular-frontend:latest
docker tag <aws_ecr_uri>/angular-frontend:latest \
  ${REGION}.ocir.io/${NAMESPACE}/vetplatform/angular-frontend:latest
docker push ${REGION}.ocir.io/${NAMESPACE}/vetplatform/angular-frontend:latest

# 5. Repeat for: node-backend, license-generator, turbonumber, docuseal, nginx
```

### Alternative: Use OCI Container Registry Mirroring

If images are in a public registry, OCIR can pull them directly. Contact your OCI admin for cross-cloud replication options.

---

## 6. Deployment Steps

```bash
# 1. Clone and enter the Terraform directory
cd terraform-oci

# 2. Initialize Terraform
terraform init

# 3. Validate configuration
terraform validate

# 4. Review the execution plan (REVIEW CAREFULLY)
terraform plan -out=tfplan

# 5. Apply (type 'yes' to confirm)
terraform apply tfplan

# 6. Save outputs
terraform output > deployment-outputs.txt
```

### Deployment Order (Terraform handles this, but FYI)

1. **Networking** — VCN, subnets, gateways, security lists, NSGs
2. **Security** — Vault, WAF policy
3. **Storage** — Object Storage bucket
4. **Database** — Autonomous Database
5. **Cache** — OCI Cache with Redis
6. **Compute** — Nginx VM
7. **OKE Cluster** — Control plane + node pools
8. **Load Balancer** — Flexible LB + backend sets
9. **DNS** — Zone + records
10. **Messaging** — Queue, Notifications topic + subscription

**Estimated deployment time:** 25-45 minutes (OKE and ADB take the longest)

---

## 7. Post-Deployment Validation

### Verify OKE Cluster

```bash
# Configure kubectl
oci ce cluster create-kubeconfig \
  --cluster-id $(terraform output -raw oke_cluster_id) \
  --file ~/.kube/config \
  --region <region> \
  --token-version 2.0.0

# Verify nodes
kubectl get nodes -o wide

# Deploy containers (use provided K8s manifests in /scripts directory)
kubectl apply -f scripts/k8s-manifests/
```

### Verify Autonomous Database

```bash
# Get connection string
terraform output adb_connection_strings

# Test connectivity from OKE pod
kubectl run dbtest --image=oraclelinux:8 --rm -it -- bash
# Inside pod:
# sqlplus admin/<password>@<connection_string>
```

### Verify Load Balancer

```bash
# Get LB public IP
terraform output lb_public_ip

# Test HTTP response
curl -I http://$(terraform output -raw lb_public_ip)
```

### Verify Object Storage

```bash
# List bucket
oci os object list --bucket-name veteran-documents --compartment-id <compartment_ocid>
```

### Verify Redis Cache

```bash
# Get Redis endpoint from Terraform output
terraform output redis_endpoint

# Test from OKE pod
kubectl run redistest --image=redis:latest --rm -it -- redis-cli -h <redis_endpoint> -p 6379 ping
```

---

## 8. Architecture Reference

```
                                ┌──────────────────────────────────────────────────────┐
   Users ──► OCI DNS ──► WAF ──►│           OCI Flexible Load Balancer                 │
                                └───────────────────────┬──────────────────────────────┘
                                                        │
                                                        ▼
                           ┌────── OCI Compute VM (Nginx Web Server) ──────┐
                           │                    OR                          │
                           │         OKE Nginx Ingress Controller          │
                           └────────────────────┬──────────────────────────┘
                                                │
                    ┌───────────────────────────────────────────────────────┐
                    │          OKE Cluster (Private Subnet)                 │
                    │                                                       │
                    │   ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │
                    │   │  Angular FE  │  │ License Gen  │  │ TurboNumber│ │
                    │   └─────────────┘  └──────────────┘  └────────────┘ │
                    │   ┌─────────────┐  ┌──────────────┐                  │
                    │   │Node Backend │  │   Docuseal   │                  │
                    │   └──────┬──────┘  └──────────────┘                  │
                    └──────────┼────────────────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
   ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐
   │  OCI Cache   │  │  Autonomous  │  │  OCI Object Storage  │
   │  with Redis  │  │   Database   │  │  (Veteran Documents) │
   └──────────────┘  └──────────────┘  └──────────┬───────────┘
                                                   │
                                    ┌──────────────┼──────────────┐
                                    ▼              ▼              ▼
                             ┌───────────┐  ┌───────────┐  ┌───────────┐
                             │OCI Queue  │  │  Doc       │  │Generative │
                             │ Service   │  │Understanding│ │  AI Svc   │
                             └───────────┘  └───────────┘  └───────────┘
                                                                │
                    ┌───────────────────────────────────────────┘
                    ▼                          ▼
         ┌──────────────────┐      ┌─────────────────────┐
         │   USPS.com API   │      │    VA REST API       │
         │ Address Validation│      │ Veteran Data/Docs   │
         └──────────────────┘      └─────────────────────┘
```

---

## 9. Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` on `terraform plan` | API key not uploaded or wrong fingerprint | Re-upload public key to OCI Console → Profile → API Keys |
| `404 NotAuthorizedOrNotFound` | Compartment OCID incorrect | Verify OCID in OCI Console → Identity → Compartments |
| OKE cluster stuck in `CREATING` | Service limits or AD capacity | Check `oci ce cluster get` for errors; request limit increase |
| ADB creation fails | Password doesn't meet complexity | 12-30 chars: 1 upper, 1 lower, 1 number, 1 special char |
| LB has no healthy backends | Security list/NSG blocking traffic | Verify ingress rules allow port 80/443 from LB subnet |
| Can't push to OCIR | Auth token expired or wrong namespace | Regenerate auth token; verify namespace with `oci os ns get` |
| Redis connection refused | NSG not allowing port 6379 | Add ingress rule for port 6379 from app subnet CIDR |

### Useful Commands

```bash
# View all resources in compartment
oci search resource structured-search \
  --query-text "query all resources where compartmentId = '<compartment_ocid>'"

# Tail OKE pod logs
kubectl logs -f deployment/<deployment-name>

# Check Terraform state
terraform state list

# Destroy everything (CAUTION)
terraform destroy
```

---

## Support & References

- [OCI Terraform Provider Docs](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [OKE Documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm)
- [Autonomous Database](https://docs.oracle.com/en-us/iaas/Content/Database/Concepts/adboverview.htm)
- [OCI Cache with Redis](https://docs.oracle.com/en-us/iaas/Content/ocicache/home.htm)
- [OCI Generative AI](https://docs.oracle.com/en-us/iaas/Content/generative-ai/home.htm)

---

*Document Version: 1.0 — Generated for Veteran Services Platform OCI Migration*
