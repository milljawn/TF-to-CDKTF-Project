// ============================================================
// Construct: Security
// OCI Vault (Key Management) — Mirrors modules/security/main.tf
// ============================================================

import { Construct } from "constructs";
import { KmsVault } from "../.gen/providers/oci/kms-vault";
import { KmsKey } from "../.gen/providers/oci/kms-key";

export interface SecurityConfig {
  compartmentOcid: string;
  prefix: string;
  freeformTags: { [key: string]: string };
}

export class SecurityConstruct extends Construct {
  public readonly vault: KmsVault;
  public readonly masterKey: KmsKey;

  constructor(scope: Construct, id: string, config: SecurityConfig) {
    super(scope, id);

    this.vault = new KmsVault(this, "vault", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-vault`,
      vaultType: "DEFAULT",
      freeformTags: config.freeformTags,
    });

    this.masterKey = new KmsKey(this, "master-key", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-master-key`,
      managementEndpoint: this.vault.managementEndpoint,
      keyShape: {
        algorithm: "AES",
        length: 32, // 256-bit
      },
      protectionMode: "HSM",
      freeformTags: config.freeformTags,
    });
  }
}
