// ============================================================
// Configuration Interface — Veteran Services Platform (OCI CDKTF)
// ============================================================
// Mirrors all variables from the original terraform-oci/variables.tf
// ============================================================

export interface VetPlatformConfig {
  // --- OCI Provider / Authentication ---
  tenancyOcid: string;
  userOcid: string;
  compartmentOcid: string;
  region: string;
  fingerprint: string;
  privateKeyPath: string;

  // --- Project Metadata ---
  projectName: string;
  environment: "dev" | "staging" | "prod";
  freeformTags?: { [key: string]: string };

  // --- Networking ---
  vcnCidr: string;
  publicSubnetCidr: string;
  privateSubnetAppCidr: string;
  privateSubnetDbCidr: string;
  privateSubnetCacheCidr: string;
  okeApiSubnetCidr: string;
  okePodSubnetCidr: string;

  // --- DNS ---
  dnsZoneName: string;
  appHostname: string;

  // --- Compute — Nginx VM ---
  nginxShape: string;
  nginxOcpus: number;
  nginxMemoryGb: number;
  nginxBootVolumeGb: number;
  sshPublicKeyPath: string;
  nginxImageOcid?: string;

  // --- OKE ---
  kubernetesVersion: string;
  okeNodeShape: string;
  okeNodeOcpus: number;
  okeNodeMemoryGb: number;
  okeNodePoolSize: number;
  okeNodeBootVolumeGb: number;

  // --- Container Images (OCIR) ---
  ocirNamespace: string;
  containerImages?: { [key: string]: string };

  // --- Autonomous Database ---
  adbAdminPassword: string;
  adbEcpuCount: number;
  adbStorageTb: number;
  adbIsFreeTier: boolean;

  // --- OCI Cache with Redis ---
  redisNodeCount: number;
  redisMemoryGb: number;

  // --- Object Storage ---
  bucketName: string;
  bucketStorageTier: string;
  bucketVersioning: boolean;

  // --- Load Balancer ---
  lbShape: string;
  lbMinBandwidthMbps: number;
  lbMaxBandwidthMbps: number;

  // --- Messaging ---
  notificationTopicName: string;
  notificationEmail: string;
  queueName: string;

  // --- WAF ---
  wafEnabled: boolean;

  // --- External Integrations (informational) ---
  vaApiEndpoint?: string;
  uspsApiEndpoint?: string;
}

/**
 * Returns sensible defaults matching terraform.tfvars.example.
 * Override with actual values in main.ts or via environment variables.
 */
export function defaultConfig(): VetPlatformConfig {
  return {
    // Auth — must be overridden
    tenancyOcid: process.env.OCI_TENANCY_OCID ?? "ocid1.tenancy.oc1..REPLACE",
    userOcid: process.env.OCI_USER_OCID ?? "ocid1.user.oc1..REPLACE",
    compartmentOcid: process.env.OCI_COMPARTMENT_OCID ?? "ocid1.compartment.oc1..REPLACE",
    region: process.env.OCI_REGION ?? "us-ashburn-1",
    fingerprint: process.env.OCI_FINGERPRINT ?? "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99",
    privateKeyPath: process.env.OCI_PRIVATE_KEY_PATH ?? "~/.oci/oci_api_key.pem",

    // Project
    projectName: "vetplatform",
    environment: "prod",
    freeformTags: {
      Project: "VeteranServicesPlatform",
      ManagedBy: "CDKTF",
      MigratedFrom: "AWS",
    },

    // Networking
    vcnCidr: "10.0.0.0/16",
    publicSubnetCidr: "10.0.1.0/24",
    privateSubnetAppCidr: "10.0.10.0/24",
    privateSubnetDbCidr: "10.0.20.0/24",
    privateSubnetCacheCidr: "10.0.30.0/24",
    okeApiSubnetCidr: "10.0.5.0/24",
    okePodSubnetCidr: "10.0.128.0/17",

    // DNS
    dnsZoneName: "example.com",
    appHostname: "vetservices",

    // Compute — Nginx VM
    nginxShape: "VM.Standard.E4.Flex",
    nginxOcpus: 2,
    nginxMemoryGb: 16,
    nginxBootVolumeGb: 50,
    sshPublicKeyPath: "~/.ssh/id_rsa.pub",

    // OKE
    kubernetesVersion: "v1.29.1",
    okeNodeShape: "VM.Standard.E4.Flex",
    okeNodeOcpus: 2,
    okeNodeMemoryGb: 16,
    okeNodePoolSize: 3,
    okeNodeBootVolumeGb: 50,

    // OCIR
    ocirNamespace: process.env.OCI_OCIR_NAMESPACE ?? "REPLACE_WITH_YOUR_NAMESPACE",
    containerImages: {
      angular_frontend: "vetplatform/angular-frontend:latest",
      node_backend: "vetplatform/node-backend:latest",
      license_generator: "vetplatform/license-generator:latest",
      turbonumber: "vetplatform/turbonumber:latest",
      docuseal: "vetplatform/docuseal:latest",
      nginx: "vetplatform/nginx:latest",
    },

    // Autonomous Database
    adbAdminPassword: process.env.ADB_ADMIN_PASSWORD ?? "REPLACE_WITH_STRONG_PASSWORD",
    adbEcpuCount: 4,
    adbStorageTb: 1,
    adbIsFreeTier: false,

    // Redis
    redisNodeCount: 1,
    redisMemoryGb: 8,

    // Object Storage
    bucketName: "veteran-documents",
    bucketStorageTier: "Standard",
    bucketVersioning: true,

    // Load Balancer
    lbShape: "flexible",
    lbMinBandwidthMbps: 10,
    lbMaxBandwidthMbps: 100,

    // Messaging
    notificationTopicName: "vetplatform-doc-alerts",
    notificationEmail: "",
    queueName: "vetplatform-user-notifications",

    // WAF
    wafEnabled: true,
  };
}
