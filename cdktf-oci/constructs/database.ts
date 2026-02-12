// ============================================================
// Construct: Autonomous Database
// Replaces: AWS RDS — Mirrors modules/database/main.tf
// ============================================================

import { Construct } from "constructs";
import { DatabaseAutonomousDatabase } from "../.gen/providers/oci/database-autonomous-database";

export interface DatabaseConfig {
  compartmentOcid: string;
  prefix: string;
  subnetId: string;
  nsgId: string;
  adminPassword: string;
  ecpuCount: number;
  storageTb: number;
  isFreeTier: boolean;
  freeformTags: { [key: string]: string };
}

export class DatabaseConstruct extends Construct {
  public readonly adb: DatabaseAutonomousDatabase;

  constructor(scope: Construct, id: string, config: DatabaseConfig) {
    super(scope, id);

    this.adb = new DatabaseAutonomousDatabase(this, "adb", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-adb`,
      dbName: config.prefix.replace(/[-_]/g, ""),
      dbWorkload: "OLTP",
      isFreeTier: config.isFreeTier,
      computeModel: "ECPU",
      computeCount: config.ecpuCount,
      dataStorageSizeInTbs: config.storageTb,
      adminPassword: config.adminPassword,
      isAutoScalingEnabled: true,
      isAutoScalingForStorageEnabled: true,
      subnetId: config.subnetId,
      nsgIds: [config.nsgId],
      isMtlsConnectionRequired: false,
      backupRetentionPeriodInDays: 30,
      isDedicated: false,
      freeformTags: config.freeformTags,
      lifecycle: {
        ignoreChanges: ["admin_password" as any],
      },
    });
  }
}
