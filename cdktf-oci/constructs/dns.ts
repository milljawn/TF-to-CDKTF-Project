// ============================================================
// Construct: OCI DNS
// Replaces: AWS Route 53 — Mirrors modules/dns/main.tf
// ============================================================

import { Construct } from "constructs";
import { DnsZone } from "../.gen/providers/oci/dns-zone";
import { DnsRrset } from "../.gen/providers/oci/dns-rrset";

export interface DnsConfig {
  compartmentOcid: string;
  prefix: string;
  zoneName: string;
  appHostname: string;
  lbPublicIp: string;
  freeformTags: { [key: string]: string };
}

export class DnsConstruct extends Construct {
  public readonly zone: DnsZone;
  public readonly appFqdn: string;

  constructor(scope: Construct, id: string, config: DnsConfig) {
    super(scope, id);

    this.appFqdn = `${config.appHostname}.${config.zoneName}`;

    this.zone = new DnsZone(this, "zone", {
      compartmentId: config.compartmentOcid,
      name: config.zoneName,
      zoneType: "PRIMARY",
      freeformTags: config.freeformTags,
    });

    new DnsRrset(this, "app-a-record", {
      zoneNameOrId: this.zone.id,
      domain: this.appFqdn,
      rtype: "A",
      compartmentId: config.compartmentOcid,
      items: [
        {
          domain: this.appFqdn,
          rtype: "A",
          rdata: config.lbPublicIp,
          ttl: 300,
        },
      ],
    });
  }
}
