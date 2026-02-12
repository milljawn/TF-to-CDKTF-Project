// ============================================================
// Construct: Object Storage
// Replaces: AWS S3 — Mirrors modules/storage/main.tf
// ============================================================

import { Construct } from "constructs";
import { ObjectstorageBucket } from "../.gen/providers/oci/objectstorage-bucket";
import { ObjectstorageObjectLifecyclePolicy } from "../.gen/providers/oci/objectstorage-object-lifecycle-policy";
import { DataOciObjectstorageNamespace } from "../.gen/providers/oci/data-oci-objectstorage-namespace";

export interface StorageConfig {
  compartmentOcid: string;
  prefix: string;
  bucketName: string;
  bucketStorageTier: string;
  bucketVersioning: boolean;
  kmsKeyId: string;
  freeformTags: { [key: string]: string };
}

export class StorageConstruct extends Construct {
  public readonly bucket: ObjectstorageBucket;
  public readonly namespace: DataOciObjectstorageNamespace;

  constructor(scope: Construct, id: string, config: StorageConfig) {
    super(scope, id);

    this.namespace = new DataOciObjectstorageNamespace(this, "ns", {
      compartmentId: config.compartmentOcid,
    });

    this.bucket = new ObjectstorageBucket(this, "veteran-docs", {
      compartmentId: config.compartmentOcid,
      namespace: this.namespace.namespace,
      name: `${config.prefix}-${config.bucketName}`,
      accessType: "NoPublicAccess",
      storageTier: config.bucketStorageTier,
      versioning: config.bucketVersioning ? "Enabled" : "Disabled",
      kmsKeyId: config.kmsKeyId,
      objectEventsEnabled: true,
      freeformTags: config.freeformTags,
    });

    new ObjectstorageObjectLifecyclePolicy(this, "lifecycle", {
      namespace: this.namespace.namespace,
      bucket: this.bucket.name,
      rules: [
        {
          name: "archive-old-docs",
          action: "INFREQUENT_ACCESS",
          timeAmount: "90",
          timeUnit: "DAYS",
          isEnabled: true,
          target: "objects",
        },
        {
          name: "archive-very-old-docs",
          action: "ARCHIVE",
          timeAmount: "365",
          timeUnit: "DAYS",
          isEnabled: true,
          target: "objects",
        },
      ],
    });
  }
}
