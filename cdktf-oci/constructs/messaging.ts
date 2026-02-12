// ============================================================
// Construct: Messaging
// Replaces: AWS SQS + AWS SNS — Mirrors modules/messaging/main.tf
// ============================================================

import { Construct } from "constructs";
import { QueueQueue } from "../.gen/providers/oci/queue-queue";
import { OnsNotificationTopic } from "../.gen/providers/oci/ons-notification-topic";
import { OnsSubscription } from "../.gen/providers/oci/ons-subscription";
import { EventsRule } from "../.gen/providers/oci/events-rule";

export interface MessagingConfig {
  compartmentOcid: string;
  prefix: string;
  notificationTopicName: string;
  notificationEmail: string;
  queueName: string;
  freeformTags: { [key: string]: string };
}

export class MessagingConstruct extends Construct {
  public readonly queue: QueueQueue;
  public readonly topic: OnsNotificationTopic;

  constructor(scope: Construct, id: string, config: MessagingConfig) {
    super(scope, id);

    // OCI Queue Service (replaces SQS)
    this.queue = new QueueQueue(this, "user-notifications", {
      compartmentId: config.compartmentOcid,
      displayName: config.queueName,
      deadLetterQueueDeliveryCount: 5,
      retentionInSeconds: 345600, // 4 days
      visibilityInSeconds: 30,
      timeoutInSeconds: 30,
      channelConsumptionLimit: 10,
      freeformTags: config.freeformTags,
    });

    // OCI Notifications Topic (replaces SNS)
    this.topic = new OnsNotificationTopic(this, "doc-alerts", {
      compartmentId: config.compartmentOcid,
      name: config.notificationTopicName,
      description:
        "Notifications for scanned veteran documents (triggers AI pipeline)",
      freeformTags: config.freeformTags,
    });

    // Email subscription (if provided)
    if (config.notificationEmail) {
      new OnsSubscription(this, "email-sub", {
        compartmentId: config.compartmentOcid,
        topicId: this.topic.id,
        protocol: "EMAIL",
        endpoint: config.notificationEmail,
        freeformTags: config.freeformTags,
      });
    }

    // Events Rule — Trigger notification on Object Storage upload
    new EventsRule(this, "doc-upload-event", {
      compartmentId: config.compartmentOcid,
      displayName: `${config.prefix}-doc-upload-event`,
      description:
        "Triggers notification when a document is uploaded to Object Storage",
      isEnabled: true,
      condition: JSON.stringify({
        eventType: [
          "com.oraclecloud.objectstorage.createobject",
          "com.oraclecloud.objectstorage.updateobject",
        ],
      }),
      actions: {
        actions: [
          {
            actionType: "ONS",
            isEnabled: true,
            topicId: this.topic.id,
            description: "Send notification on document upload",
          },
        ],
      },
      freeformTags: config.freeformTags,
    });
  }
}
