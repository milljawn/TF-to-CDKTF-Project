// ============================================================
// Construct: OKE (Oracle Kubernetes Engine)
// Replaces: AWS ECS Fargate (6 containers)
// Mirrors: modules/oke/main.tf
// ============================================================

import { Construct } from "constructs";
import { ContainerengineCluster } from "../.gen/providers/oci/containerengine-cluster";
import { ContainerengineNodePool } from "../.gen/providers/oci/containerengine-node-pool";

export interface OkeConfig {
  compartmentOcid: string;
  tenancyOcid: string;
  prefix: string;
  vcnId: string;
  apiSubnetId: string;
  workerSubnetId: string;
  podSubnetId: string;
  lbSubnetId: string;
  nsgId: string;
  kubernetesVersion: string;
  nodeShape: string;
  nodeOcpus: number;
  nodeMemoryGb: number;
  nodePoolSize: number;
  nodeBootVolumeGb: number;
  imageId: string;
  sshPublicKey: string;
  availabilityDomains: string[];
  freeformTags: { [key: string]: string };
}

export class OkeConstruct extends Construct {
  public readonly cluster: ContainerengineCluster;
  public readonly nodePool: ContainerengineNodePool;

  constructor(scope: Construct, id: string, config: OkeConfig) {
    super(scope, id);

    this.cluster = new ContainerengineCluster(this, "cluster", {
      compartmentId: config.compartmentOcid,
      kubernetesVersion: config.kubernetesVersion,
      name: `${config.prefix}-oke-cluster`,
      vcnId: config.vcnId,
      type: "ENHANCED_CLUSTER",
      clusterPodNetworkOptions: [{ cniType: "OCI_VCN_IP_NATIVE" }],
      endpointConfig: {
        isPublicIpEnabled: false,
        subnetId: config.apiSubnetId,
        nsgIds: [config.nsgId],
      },
      options: {
        serviceLbSubnetIds: [config.lbSubnetId],
        kubernetesNetworkConfig: {
          servicesCidr: "10.96.0.0/16",
          podsCidr: "10.244.0.0/16",
        },
        persistentVolumeConfig: {
          freeformTags: config.freeformTags,
        },
      },
      freeformTags: config.freeformTags,
    });

    this.nodePool = new ContainerengineNodePool(this, "workers", {
      compartmentId: config.compartmentOcid,
      clusterId: this.cluster.id,
      kubernetesVersion: config.kubernetesVersion,
      name: `${config.prefix}-node-pool`,
      nodeShape: config.nodeShape,
      nodeShapeConfig: {
        ocpus: config.nodeOcpus,
        memoryInGbs: config.nodeMemoryGb,
      },
      nodeSourceDetails: {
        sourceType: "IMAGE",
        imageId: config.imageId,
        bootVolumeSizeInGbs: String(config.nodeBootVolumeGb),
      },
      nodeConfigDetails: {
        size: config.nodePoolSize,
        placementConfigs: config.availabilityDomains.map((ad) => ({
          availabilityDomain: ad,
          subnetId: config.workerSubnetId,
        })),
        nsgIds: [config.nsgId],
        freeformTags: config.freeformTags,
        nodePoolPodNetworkOptionDetails: {
          cniType: "OCI_VCN_IP_NATIVE",
          podSubnetIds: [config.podSubnetId],
          podNsgIds: [config.nsgId],
        },
      },
      sshPublicKey: config.sshPublicKey,
      freeformTags: config.freeformTags,
    });
  }
}
