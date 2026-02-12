// ============================================================
// Construct: Flexible Load Balancer + WAF
// Replaces: AWS Application Load Balancer
// Mirrors: modules/load-balancer/main.tf
// ============================================================

import { Construct } from "constructs";
import { LoadBalancerLoadBalancer } from "../.gen/providers/oci/load-balancer-load-balancer";
import { LoadBalancerBackendSet } from "../.gen/providers/oci/load-balancer-backend-set";
import { LoadBalancerBackend } from "../.gen/providers/oci/load-balancer-backend";
import { LoadBalancerListener } from "../.gen/providers/oci/load-balancer-listener";
import { WafWebAppFirewallPolicy } from "../.gen/providers/oci/waf-web-app-firewall-policy";
import { WafWebAppFirewall } from "../.gen/providers/oci/waf-web-app-firewall";

export interface LoadBalancerConfig {
  compartmentOcid: string;
  prefix: string;
  subnetId: string;
  nsgId: string;
  shape: string;
  minBandwidthMbps: number;
  maxBandwidthMbps: number;
  nginxPrivateIp: string;
  wafEnabled: boolean;
  freeformTags: { [key: string]: string };
}

export class LoadBalancerConstruct extends Construct {
  public readonly lb: LoadBalancerLoadBalancer;

  constructor(scope: Construct, id: string, config: LoadBalancerConfig) {
    super(scope, id);

    this.lb = new LoadBalancerLoadBalancer(this, "lb", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-lb`,
      shape: config.shape,
      subnetIds: [config.subnetId],
      networkSecurityGroupIds: [config.nsgId],
      isPrivate: false,
      shapeDetails: {
        minimumBandwidthInMbps: config.minBandwidthMbps,
        maximumBandwidthInMbps: config.maxBandwidthMbps,
      },
      freeformTags: config.freeformTags,
    });

    const backendSet = new LoadBalancerBackendSet(this, "bs-nginx", {
      loadBalancerId: this.lb.id,
      name: `${config.prefix}-bs-nginx`,
      policy: "ROUND_ROBIN",
      healthChecker: {
        protocol: "HTTP",
        port: 80,
        urlPath: "/health",
        intervalMs: 10000,
        timeoutInMillis: 3000,
        retries: 3,
        returnCode: 200,
      },
    });

    new LoadBalancerBackend(this, "backend-nginx", {
      loadBalancerId: this.lb.id,
      backendsetName: backendSet.name,
      ipAddress: config.nginxPrivateIp,
      port: 80,
    });

    new LoadBalancerListener(this, "listener-http", {
      loadBalancerId: this.lb.id,
      name: `${config.prefix}-listener-http`,
      defaultBackendSetName: backendSet.name,
      port: 80,
      protocol: "HTTP",
      connectionConfiguration: {
        idleTimeoutInSeconds: "300",
      },
    });

    // WAF
    if (config.wafEnabled) {
      const wafPolicy = new WafWebAppFirewallPolicy(this, "waf-policy", {
        compartmentId: config.compartmentOcid,
        displayName: `${config.prefix}-waf-policy`,
        actions: [
          { name: "allowAction", type: "ALLOW" },
          {
            name: "return403",
            type: "RETURN_HTTP_RESPONSE",
            code: 403,
            body: { type: "STATIC_TEXT", text: "Access Denied" },
            headers: [{ name: "Content-Type", value: "text/plain" }],
          },
        ],
        requestProtection: {
          rules: [
            {
              name: "OWASP-CRS",
              type: "PROTECTION",
              actionName: "return403",
              isBodyInspectionEnabled: true,
              protectionCapabilities: [
                { key: "920360", version: 1 },
                { key: "941100", version: 1 },
              ],
            },
          ],
        },
        freeformTags: config.freeformTags,
      });

      new WafWebAppFirewall(this, "waf", {
        compartmentId: config.compartmentOcid,
        displayName: `${config.prefix}-waf`,
        backendType: "LOAD_BALANCER",
        loadBalancerId: this.lb.id,
        webAppFirewallPolicyId: wafPolicy.id,
        freeformTags: config.freeformTags,
      });
    }
  }
}
