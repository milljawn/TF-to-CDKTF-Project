// ============================================================
// Construct: OCI Cache with Redis
// Replaces: AWS ElastiCache for Redis — Mirrors modules/cache/main.tf
// ============================================================

import { Construct } from "constructs";
import { RedisRedisCluster } from "../.gen/providers/oci/redis-redis-cluster";

export interface CacheConfig {
  compartmentOcid: string;
  prefix: string;
  subnetId: string;
  nsgId: string;
  nodeCount: number;
  memoryGb: number;
  freeformTags: { [key: string]: string };
}

export class CacheConstruct extends Construct {
  public readonly redis: RedisRedisCluster;

  constructor(scope: Construct, id: string, config: CacheConfig) {
    super(scope, id);

    this.redis = new RedisRedisCluster(this, "redis", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-redis`,
      subnetId: config.subnetId,
      nodeCount: config.nodeCount,
      nodeMemoryInGbs: config.memoryGb,
      softwareVersion: "REDIS_7_0",
      freeformTags: config.freeformTags,
    });
  }
}
