// ============================================================
// OCI CDKTF — Veteran Services Platform
// Root Stack
// ============================================================
// Deploys the full OCI infrastructure equivalent of the AWS
// architecture: VCN, OKE, Autonomous DB, Redis, Object Storage,
// Load Balancer, DNS, WAF, Messaging, and AI Services.
//
// This is the CDKTF equivalent of terraform-oci/main.tf.
// ============================================================

import { App, TerraformStack, TerraformOutput, Fn } from "cdktf";
import { Construct } from "constructs";
import * as fs from "fs";

// OCI Provider
import { OciProvider } from "./.gen/providers/oci/provider";

// Data Sources
import { DataOciIdentityAvailabilityDomains } from "./.gen/providers/oci/data-oci-identity-availability-domains";
import { DataOciCoreImages } from "./.gen/providers/oci/data-oci-core-images";
import { DataOciCoreServices } from "./.gen/providers/oci/data-oci-core-services";

// Constructs (mirrors Terraform modules)
import { NetworkingConstruct } from "./constructs/networking";
import { SecurityConstruct } from "./constructs/security";
import { StorageConstruct } from "./constructs/storage";
import { DatabaseConstruct } from "./constructs/database";
import { CacheConstruct } from "./constructs/cache";
import { ComputeConstruct } from "./constructs/compute";
import { OkeConstruct } from "./constructs/oke";
import { LoadBalancerConstruct } from "./constructs/load-balancer";
import { DnsConstruct } from "./constructs/dns";
import { MessagingConstruct } from "./constructs/messaging";
import { AiServicesConstruct } from "./constructs/ai-services";

// Configuration
import { VetPlatformConfig, defaultConfig } from "./config";

class VetPlatformStack extends TerraformStack {
  constructor(scope: Construct, id: string, config: VetPlatformConfig) {
    super(scope, id);

    const prefix = `${config.projectName}-${config.environment}`;
    const allTags: { [key: string]: string } = {
      ...(config.freeformTags ?? {}),
      Environment: config.environment,
    };

    // ----------------------------------------------------------
    // Provider Configuration
    // ----------------------------------------------------------
    new OciProvider(this, "oci", {
      tenancyOcid: config.tenancyOcid,
      userOcid: config.userOcid,
      fingerprint: config.fingerprint,
      privateKeyPath: config.privateKeyPath,
      region: config.region,
    });

    // ----------------------------------------------------------
    // Data Sources
    // ----------------------------------------------------------
    const ads = new DataOciIdentityAvailabilityDomains(this, "ads", {
      compartmentId: config.tenancyOcid,
    });

    const oracleLinuxImages = new DataOciCoreImages(this, "oracle-linux", {
      compartmentId: config.compartmentOcid,
      operatingSystem: "Oracle Linux",
      operatingSystemVersion: "8",
      shape: config.nginxShape,
      sortBy: "TIMECREATED",
      sortOrder: "DESC",
      filter: [
        {
          name: "display_name",
          values: ["^Oracle-Linux-8\\.\\d+-\\d{4}\\.\\d{2}\\.\\d{2}-\\d+$"],
          regex: true,
        },
      ],
    });

    const allServices = new DataOciCoreServices(this, "all-services", {
      filter: [
        {
          name: "name",
          values: ["All .* Services In Oracle Services Network"],
          regex: true,
        },
      ],
    });

    // Resolve image ID: use explicit OCID if provided, else auto-detect
    const imageId =
      config.nginxImageOcid && config.nginxImageOcid !== ""
        ? config.nginxImageOcid
        : `\${data.oci_core_images.${oracleLinuxImages.friendlyUniqueId}.images[0].id}`;

    // Read SSH public key
    const sshKeyPath = config.sshPublicKeyPath.replace(
      "~",
      process.env.HOME ?? ""
    );
    let sshPublicKey: string;
    try {
      sshPublicKey = fs.readFileSync(sshKeyPath, "utf-8").trim();
    } catch {
      sshPublicKey = "REPLACE_WITH_YOUR_SSH_PUBLIC_KEY";
    }

    // Helper: extract AD name at index
    const adName = (index: number): string =>
      `\${data.oci_identity_availability_domains.${ads.friendlyUniqueId}.availability_domains[${index}].name}`;

    // Helper: extract service attribute at index
    const svcAttr = (attr: string): string =>
      `\${data.oci_core_services.${allServices.friendlyUniqueId}.services[0].${attr}}`;

    // ----------------------------------------------------------
    // Module: Networking
    // ----------------------------------------------------------
    const networking = new NetworkingConstruct(this, "networking", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      vcnCidr: config.vcnCidr,
      publicSubnetCidr: config.publicSubnetCidr,
      privateSubnetAppCidr: config.privateSubnetAppCidr,
      privateSubnetDbCidr: config.privateSubnetDbCidr,
      privateSubnetCacheCidr: config.privateSubnetCacheCidr,
      okeApiSubnetCidr: config.okeApiSubnetCidr,
      okePodSubnetCidr: config.okePodSubnetCidr,
      allServicesId: svcAttr("id"),
      allServicesCidr: svcAttr("cidr_block"),
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Security (Vault)
    // ----------------------------------------------------------
    const security = new SecurityConstruct(this, "security", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Object Storage
    // ----------------------------------------------------------
    const storage = new StorageConstruct(this, "storage", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      bucketName: config.bucketName,
      bucketStorageTier: config.bucketStorageTier,
      bucketVersioning: config.bucketVersioning,
      kmsKeyId: security.masterKey.id,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Autonomous Database
    // ----------------------------------------------------------
    const database = new DatabaseConstruct(this, "database", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      subnetId: networking.privateSubnetDb.id,
      nsgId: networking.nsgDatabase.id,
      adminPassword: config.adbAdminPassword,
      ecpuCount: config.adbEcpuCount,
      storageTb: config.adbStorageTb,
      isFreeTier: config.adbIsFreeTier,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: OCI Cache with Redis
    // ----------------------------------------------------------
    const cache = new CacheConstruct(this, "cache", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      subnetId: networking.privateSubnetCache.id,
      nsgId: networking.nsgCache.id,
      nodeCount: config.redisNodeCount,
      memoryGb: config.redisMemoryGb,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Compute (Nginx VM)
    // ----------------------------------------------------------
    const compute = new ComputeConstruct(this, "compute", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      availabilityDomain: adName(0),
      subnetId: networking.privateSubnetApp.id,
      nsgId: networking.nsgApp.id,
      shape: config.nginxShape,
      ocpus: config.nginxOcpus,
      memoryGb: config.nginxMemoryGb,
      bootVolumeGb: config.nginxBootVolumeGb,
      imageId,
      sshPublicKey,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: OKE (Oracle Kubernetes Engine)
    // ----------------------------------------------------------
    const oke = new OkeConstruct(this, "oke", {
      compartmentOcid: config.compartmentOcid,
      tenancyOcid: config.tenancyOcid,
      prefix,
      vcnId: networking.vcn.id,
      apiSubnetId: networking.okeApiSubnet.id,
      workerSubnetId: networking.privateSubnetApp.id,
      podSubnetId: networking.okePodSubnet.id,
      lbSubnetId: networking.publicSubnet.id,
      nsgId: networking.nsgApp.id,
      kubernetesVersion: config.kubernetesVersion,
      nodeShape: config.okeNodeShape,
      nodeOcpus: config.okeNodeOcpus,
      nodeMemoryGb: config.okeNodeMemoryGb,
      nodePoolSize: config.okeNodePoolSize,
      nodeBootVolumeGb: config.okeNodeBootVolumeGb,
      imageId,
      sshPublicKey,
      availabilityDomains: [adName(0)],
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Load Balancer
    // ----------------------------------------------------------
    const loadBalancer = new LoadBalancerConstruct(this, "load-balancer", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      subnetId: networking.publicSubnet.id,
      nsgId: networking.nsgLb.id,
      shape: config.lbShape,
      minBandwidthMbps: config.lbMinBandwidthMbps,
      maxBandwidthMbps: config.lbMaxBandwidthMbps,
      nginxPrivateIp: compute.nginx.privateIp,
      wafEnabled: config.wafEnabled,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: DNS
    // ----------------------------------------------------------
    const dns = new DnsConstruct(this, "dns", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      zoneName: config.dnsZoneName,
      appHostname: config.appHostname,
      lbPublicIp: `\${oci_load_balancer_load_balancer.${loadBalancer.lb.friendlyUniqueId}.ip_address_details[0].ip_address}`,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: Messaging (Queue + Notifications)
    // ----------------------------------------------------------
    const messaging = new MessagingConstruct(this, "messaging", {
      compartmentOcid: config.compartmentOcid,
      prefix,
      notificationTopicName: config.notificationTopicName,
      notificationEmail: config.notificationEmail,
      queueName: config.queueName,
      freeformTags: allTags,
    });

    // ----------------------------------------------------------
    // Module: AI Services (IAM policies)
    // ----------------------------------------------------------
    new AiServicesConstruct(this, "ai-services", {
      compartmentOcid: config.compartmentOcid,
      tenancyOcid: config.tenancyOcid,
      prefix,
      freeformTags: allTags,
    });

    // ===========================================================
    // Outputs — Mirrors terraform-oci/outputs.tf
    // ===========================================================

    // Networking
    new TerraformOutput(this, "vcn_id", {
      description: "OCID of the VCN",
      value: networking.vcn.id,
    });
    new TerraformOutput(this, "vcn_cidr", {
      description: "VCN CIDR block",
      value: config.vcnCidr,
    });

    // OKE
    new TerraformOutput(this, "oke_cluster_id", {
      description: "OCID of the OKE cluster",
      value: oke.cluster.id,
    });
    new TerraformOutput(this, "oke_kubeconfig_command", {
      description: "Command to configure kubectl",
      value: `oci ce cluster create-kubeconfig --cluster-id \${${oke.cluster.fqn}.id} --file ~/.kube/config --region ${config.region} --token-version 2.0.0`,
    });
    new TerraformOutput(this, "oke_node_pool_id", {
      description: "OCID of the OKE node pool",
      value: oke.nodePool.id,
    });

    // Compute
    new TerraformOutput(this, "nginx_instance_id", {
      description: "OCID of the Nginx compute instance",
      value: compute.nginx.id,
    });
    new TerraformOutput(this, "nginx_private_ip", {
      description: "Private IP of the Nginx VM",
      value: compute.nginx.privateIp,
    });

    // Load Balancer
    new TerraformOutput(this, "lb_id", {
      description: "OCID of the Flexible Load Balancer",
      value: loadBalancer.lb.id,
    });
    new TerraformOutput(this, "lb_public_ip", {
      description: "Public IP address of the Load Balancer",
      value: `\${oci_load_balancer_load_balancer.${loadBalancer.lb.friendlyUniqueId}.ip_address_details[0].ip_address}`,
    });

    // DNS
    new TerraformOutput(this, "app_url", {
      description: "Full application URL",
      value: `https://${config.appHostname}.${config.dnsZoneName}`,
    });
    new TerraformOutput(this, "dns_zone_id", {
      description: "OCID of the DNS zone",
      value: dns.zone.id,
    });

    // Database
    new TerraformOutput(this, "adb_id", {
      description: "OCID of the Autonomous Database",
      value: database.adb.id,
    });
    new TerraformOutput(this, "adb_connection_strings", {
      description: "Autonomous Database connection strings",
      value: database.adb.connectionStrings,
      sensitive: true,
    });
    new TerraformOutput(this, "adb_private_endpoint", {
      description: "Autonomous Database private endpoint",
      value: database.adb.privateEndpoint,
    });

    // Cache
    new TerraformOutput(this, "redis_id", {
      description: "OCID of the OCI Cache (Redis) cluster",
      value: cache.redis.id,
    });
    new TerraformOutput(this, "redis_endpoint", {
      description: "Redis primary endpoint hostname",
      value: cache.redis.primaryEndpointIpAddress,
    });
    new TerraformOutput(this, "redis_port", {
      description: "Redis port",
      value: "6379",
    });

    // Storage
    new TerraformOutput(this, "bucket_name", {
      description: "Name of the Object Storage bucket",
      value: storage.bucket.name,
    });
    new TerraformOutput(this, "bucket_namespace", {
      description: "Object Storage namespace",
      value: storage.namespace.namespace,
    });

    // Messaging
    new TerraformOutput(this, "notification_topic_id", {
      description: "OCID of the Notifications topic",
      value: messaging.topic.id,
    });
    new TerraformOutput(this, "queue_id", {
      description: "OCID of the OCI Queue",
      value: messaging.queue.id,
    });
    new TerraformOutput(this, "queue_endpoint", {
      description: "OCI Queue endpoint URL",
      value: messaging.queue.messagesEndpoint,
    });

    // Security
    new TerraformOutput(this, "vault_id", {
      description: "OCID of the OCI Vault",
      value: security.vault.id,
    });

    // Container Registry
    new TerraformOutput(this, "ocir_login_command", {
      description: "Docker login command for OCIR",
      value: `docker login ${config.region}.ocir.io`,
    });
    new TerraformOutput(this, "ocir_image_prefix", {
      description: "Base URI for OCIR images",
      value: `${config.region}.ocir.io/${config.ocirNamespace}`,
    });
  }
}

// ===========================================================
// App Entrypoint
// ===========================================================
const app = new App();
new VetPlatformStack(app, "vetplatform-oci", defaultConfig());
app.synth();
