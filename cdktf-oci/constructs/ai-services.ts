// ============================================================
// Construct: AI Services
// Replaces: AWS Textract + AWS Bedrock
// OCI Document Understanding + OCI Generative AI Service
// Mirrors: modules/ai-services/main.tf
// ============================================================

import { Construct } from "constructs";
import { IdentityDynamicGroup } from "../.gen/providers/oci/identity-dynamic-group";
import { IdentityPolicy } from "../.gen/providers/oci/identity-policy";

export interface AiServicesConfig {
  compartmentOcid: string;
  tenancyOcid: string;
  prefix: string;
  freeformTags: { [key: string]: string };
}

export class AiServicesConstruct extends Construct {
  public readonly dynamicGroup: IdentityDynamicGroup;

  constructor(scope: Construct, id: string, config: AiServicesConfig) {
    super(scope, id);

    // Dynamic Group for OKE pods to call AI services
    this.dynamicGroup = new IdentityDynamicGroup(this, "oke-ai-access", {
      compartmentId: config.tenancyOcid,
      name: `${config.prefix}-oke-ai-access`,
      description: "OKE pods that can access OCI AI Services",
      matchingRule: `ALL {resource.type = 'cluster', resource.compartment.id = '${config.compartmentOcid}'}`,
      freeformTags: config.freeformTags,
    });

    // IAM Policy — Document Understanding (replaces Textract)
    new IdentityPolicy(this, "doc-understanding-policy", {
      compartmentId: config.compartmentOcid,
      name: `${config.prefix}-doc-understanding-policy`,
      description:
        "Allow OKE workloads to use OCI Document Understanding (replaces Textract)",
      statements: [
        `Allow dynamic-group ${this.dynamicGroup.name} to use ai-service-document-family in compartment id ${config.compartmentOcid}`,
        `Allow dynamic-group ${this.dynamicGroup.name} to read objectstorage-namespaces in compartment id ${config.compartmentOcid}`,
        `Allow dynamic-group ${this.dynamicGroup.name} to read buckets in compartment id ${config.compartmentOcid}`,
        `Allow dynamic-group ${this.dynamicGroup.name} to read objects in compartment id ${config.compartmentOcid}`,
      ],
      freeformTags: config.freeformTags,
    });

    // IAM Policy — Generative AI (replaces Bedrock)
    new IdentityPolicy(this, "generative-ai-policy", {
      compartmentId: config.compartmentOcid,
      name: `${config.prefix}-generative-ai-policy`,
      description:
        "Allow OKE workloads to use OCI Generative AI (replaces Bedrock)",
      statements: [
        `Allow dynamic-group ${this.dynamicGroup.name} to use generative-ai-family in compartment id ${config.compartmentOcid}`,
      ],
      freeformTags: config.freeformTags,
    });
  }
}
