// ============================================================
// Construct: Networking
// VCN, Subnets, Gateways, Route Tables, Security Lists, NSGs
// Mirrors: terraform-oci/modules/networking/main.tf
// ============================================================

import { Construct } from "constructs";
import { CoreVcn } from "../.gen/providers/oci/core-vcn";
import { CoreInternetGateway } from "../.gen/providers/oci/core-internet-gateway";
import { CoreNatGateway } from "../.gen/providers/oci/core-nat-gateway";
import { CoreServiceGateway } from "../.gen/providers/oci/core-service-gateway";
import { CoreRouteTable } from "../.gen/providers/oci/core-route-table";
import { CoreSecurityList } from "../.gen/providers/oci/core-security-list";
import { CoreSubnet } from "../.gen/providers/oci/core-subnet";
import { CoreNetworkSecurityGroup } from "../.gen/providers/oci/core-network-security-group";
import { CoreNetworkSecurityGroupSecurityRule } from "../.gen/providers/oci/core-network-security-group-security-rule";

export interface NetworkingConfig {
  compartmentOcid: string;
  prefix: string;
  vcnCidr: string;
  publicSubnetCidr: string;
  privateSubnetAppCidr: string;
  privateSubnetDbCidr: string;
  privateSubnetCacheCidr: string;
  okeApiSubnetCidr: string;
  okePodSubnetCidr: string;
  allServicesId: string;
  allServicesCidr: string;
  freeformTags: { [key: string]: string };
}

export class NetworkingConstruct extends Construct {
  public readonly vcn: CoreVcn;
  public readonly publicSubnet: CoreSubnet;
  public readonly privateSubnetApp: CoreSubnet;
  public readonly privateSubnetDb: CoreSubnet;
  public readonly privateSubnetCache: CoreSubnet;
  public readonly okeApiSubnet: CoreSubnet;
  public readonly okePodSubnet: CoreSubnet;
  public readonly nsgLb: CoreNetworkSecurityGroup;
  public readonly nsgApp: CoreNetworkSecurityGroup;
  public readonly nsgDatabase: CoreNetworkSecurityGroup;
  public readonly nsgCache: CoreNetworkSecurityGroup;

  constructor(scope: Construct, id: string, config: NetworkingConfig) {
    super(scope, id);

    // ---- VCN ----
    this.vcn = new CoreVcn(this, "vcn", {
      compartmentId: config.compartmentOcid,
      cidrBlocks: [config.vcnCidr],
      displayName: `${config.prefix}-vcn`,
      dnsLabel: config.prefix.replace(/-/g, ""),
      freeformTags: config.freeformTags,
    });

    // ---- Gateways ----
    const igw = new CoreInternetGateway(this, "igw", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-igw`,
      enabled: true,
      freeformTags: config.freeformTags,
    });

    const natgw = new CoreNatGateway(this, "natgw", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-natgw`,
      freeformTags: config.freeformTags,
    });

    const svcgw = new CoreServiceGateway(this, "svcgw", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-svcgw`,
      services: [{ serviceId: config.allServicesId }],
      freeformTags: config.freeformTags,
    });

    // ---- Route Tables ----
    const publicRt = new CoreRouteTable(this, "rt-public", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-rt-public`,
      routeRules: [
        {
          networkEntityId: igw.id,
          destination: "0.0.0.0/0",
          destinationType: "CIDR_BLOCK",
          description: "Internet access via IGW",
        },
      ],
      freeformTags: config.freeformTags,
    });

    const privateRt = new CoreRouteTable(this, "rt-private", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-rt-private`,
      routeRules: [
        {
          networkEntityId: natgw.id,
          destination: "0.0.0.0/0",
          destinationType: "CIDR_BLOCK",
          description: "Outbound internet via NAT Gateway",
        },
        {
          networkEntityId: svcgw.id,
          destination: config.allServicesCidr,
          destinationType: "SERVICE_CIDR_BLOCK",
          description: "OCI services via Service Gateway",
        },
      ],
      freeformTags: config.freeformTags,
    });

    // ---- Security Lists ----
    const publicSl = new CoreSecurityList(this, "sl-public", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-sl-public`,
      ingressSecurityRules: [
        {
          protocol: "6",
          source: "0.0.0.0/0",
          sourceType: "CIDR_BLOCK",
          description: "HTTPS from internet",
          tcpOptions: { min: 443, max: 443 },
        },
        {
          protocol: "6",
          source: "0.0.0.0/0",
          sourceType: "CIDR_BLOCK",
          description: "HTTP from internet (redirect to HTTPS)",
          tcpOptions: { min: 80, max: 80 },
        },
      ],
      egressSecurityRules: [
        {
          protocol: "all",
          destination: "0.0.0.0/0",
          description: "Allow all outbound",
        },
      ],
      freeformTags: config.freeformTags,
    });

    const privateSl = new CoreSecurityList(this, "sl-private", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-sl-private`,
      ingressSecurityRules: [
        {
          protocol: "6",
          source: config.vcnCidr,
          sourceType: "CIDR_BLOCK",
          description: "All TCP within VCN",
        },
        {
          protocol: "1",
          source: config.vcnCidr,
          sourceType: "CIDR_BLOCK",
          description: "ICMP within VCN",
        },
      ],
      egressSecurityRules: [
        {
          protocol: "all",
          destination: "0.0.0.0/0",
          description: "Allow all outbound",
        },
      ],
      freeformTags: config.freeformTags,
    });

    // ---- Subnets ----
    this.publicSubnet = new CoreSubnet(this, "subnet-public", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.publicSubnetCidr,
      displayName: `${config.prefix}-subnet-public`,
      dnsLabel: "pub",
      prohibitPublicIpOnVnic: false,
      routeTableId: publicRt.id,
      securityListIds: [publicSl.id],
      freeformTags: config.freeformTags,
    });

    this.privateSubnetApp = new CoreSubnet(this, "subnet-app", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.privateSubnetAppCidr,
      displayName: `${config.prefix}-subnet-app`,
      dnsLabel: "app",
      prohibitPublicIpOnVnic: true,
      routeTableId: privateRt.id,
      securityListIds: [privateSl.id],
      freeformTags: config.freeformTags,
    });

    this.privateSubnetDb = new CoreSubnet(this, "subnet-db", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.privateSubnetDbCidr,
      displayName: `${config.prefix}-subnet-db`,
      dnsLabel: "db",
      prohibitPublicIpOnVnic: true,
      routeTableId: privateRt.id,
      securityListIds: [privateSl.id],
      freeformTags: config.freeformTags,
    });

    this.privateSubnetCache = new CoreSubnet(this, "subnet-cache", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.privateSubnetCacheCidr,
      displayName: `${config.prefix}-subnet-cache`,
      dnsLabel: "cache",
      prohibitPublicIpOnVnic: true,
      routeTableId: privateRt.id,
      securityListIds: [privateSl.id],
      freeformTags: config.freeformTags,
    });

    this.okeApiSubnet = new CoreSubnet(this, "subnet-oke-api", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.okeApiSubnetCidr,
      displayName: `${config.prefix}-subnet-oke-api`,
      dnsLabel: "okeapi",
      prohibitPublicIpOnVnic: true,
      routeTableId: privateRt.id,
      securityListIds: [privateSl.id],
      freeformTags: config.freeformTags,
    });

    this.okePodSubnet = new CoreSubnet(this, "subnet-oke-pods", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      cidrBlock: config.okePodSubnetCidr,
      displayName: `${config.prefix}-subnet-oke-pods`,
      dnsLabel: "okepods",
      prohibitPublicIpOnVnic: true,
      routeTableId: privateRt.id,
      securityListIds: [privateSl.id],
      freeformTags: config.freeformTags,
    });

    // ---- Network Security Groups ----
    this.nsgLb = new CoreNetworkSecurityGroup(this, "nsg-lb", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-nsg-lb`,
      freeformTags: config.freeformTags,
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-lb-ingress-https", {
      networkSecurityGroupId: this.nsgLb.id,
      direction: "INGRESS",
      protocol: "6",
      source: "0.0.0.0/0",
      sourceType: "CIDR_BLOCK",
      description: "HTTPS from internet",
      tcpOptions: { destinationPortRange: { min: 443, max: 443 } },
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-lb-ingress-http", {
      networkSecurityGroupId: this.nsgLb.id,
      direction: "INGRESS",
      protocol: "6",
      source: "0.0.0.0/0",
      sourceType: "CIDR_BLOCK",
      description: "HTTP from internet",
      tcpOptions: { destinationPortRange: { min: 80, max: 80 } },
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-lb-egress-app", {
      networkSecurityGroupId: this.nsgLb.id,
      direction: "EGRESS",
      protocol: "6",
      destination: config.privateSubnetAppCidr,
      destinationType: "CIDR_BLOCK",
      description: "LB to app subnet",
      tcpOptions: { destinationPortRange: { min: 80, max: 80 } },
    });

    // App NSG
    this.nsgApp = new CoreNetworkSecurityGroup(this, "nsg-app", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-nsg-app`,
      freeformTags: config.freeformTags,
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-app-from-lb", {
      networkSecurityGroupId: this.nsgApp.id,
      direction: "INGRESS",
      protocol: "6",
      source: this.nsgLb.id,
      sourceType: "NETWORK_SECURITY_GROUP",
      description: "HTTP from Load Balancer",
      tcpOptions: { destinationPortRange: { min: 80, max: 80 } },
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-app-internal", {
      networkSecurityGroupId: this.nsgApp.id,
      direction: "INGRESS",
      protocol: "6",
      source: config.privateSubnetAppCidr,
      sourceType: "CIDR_BLOCK",
      description: "Internal app-to-app (OKE pods, GraphQL, etc.)",
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-app-egress-all", {
      networkSecurityGroupId: this.nsgApp.id,
      direction: "EGRESS",
      protocol: "all",
      destination: "0.0.0.0/0",
      destinationType: "CIDR_BLOCK",
      description: "Allow all outbound from app",
    });

    // Database NSG
    this.nsgDatabase = new CoreNetworkSecurityGroup(this, "nsg-database", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-nsg-database`,
      freeformTags: config.freeformTags,
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-db-from-app", {
      networkSecurityGroupId: this.nsgDatabase.id,
      direction: "INGRESS",
      protocol: "6",
      source: this.nsgApp.id,
      sourceType: "NETWORK_SECURITY_GROUP",
      description: "Oracle SQL*Net from app tier",
      tcpOptions: { destinationPortRange: { min: 1522, max: 1522 } },
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-db-egress", {
      networkSecurityGroupId: this.nsgDatabase.id,
      direction: "EGRESS",
      protocol: "6",
      destination: config.privateSubnetAppCidr,
      destinationType: "CIDR_BLOCK",
      description: "Response to app tier",
    });

    // Cache NSG
    this.nsgCache = new CoreNetworkSecurityGroup(this, "nsg-cache", {
      compartmentId: config.compartmentOcid,
      vcnId: this.vcn.id,
      displayName: `${config.prefix}-nsg-cache`,
      freeformTags: config.freeformTags,
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-cache-from-app", {
      networkSecurityGroupId: this.nsgCache.id,
      direction: "INGRESS",
      protocol: "6",
      source: this.nsgApp.id,
      sourceType: "NETWORK_SECURITY_GROUP",
      description: "Redis from app tier",
      tcpOptions: { destinationPortRange: { min: 6379, max: 6379 } },
    });

    new CoreNetworkSecurityGroupSecurityRule(this, "nsg-cache-egress", {
      networkSecurityGroupId: this.nsgCache.id,
      direction: "EGRESS",
      protocol: "6",
      destination: config.privateSubnetAppCidr,
      destinationType: "CIDR_BLOCK",
      description: "Response to app tier",
    });
  }
}
