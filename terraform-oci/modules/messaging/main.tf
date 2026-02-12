# ============================================================
# Module: Messaging
# Replaces: AWS SQS + AWS SNS
# Role: User notification queue + scanned doc event alerts
# ============================================================

variable "compartment_ocid" { type = string }
variable "prefix" { type = string }
variable "notification_topic_name" { type = string }
variable "notification_email" { type = string }
variable "queue_name" { type = string }
variable "freeform_tags" { type = map(string) }

# ----------------------------------------------------------
# OCI Queue Service (replaces SQS)
# ----------------------------------------------------------
resource "oci_queue_queue" "user_notifications" {
  compartment_id = var.compartment_ocid
  display_name   = var.queue_name

  # Queue configuration
  dead_letter_queue_delivery_count = 5
  retention_in_seconds             = 345600  # 4 days
  visibility_in_seconds            = 30
  timeout_in_seconds               = 30
  channel_consumption_limit        = 10

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# OCI Notifications Topic (replaces SNS)
# ----------------------------------------------------------
resource "oci_ons_notification_topic" "doc_alerts" {
  compartment_id = var.compartment_ocid
  name           = var.notification_topic_name
  description    = "Notifications for scanned veteran documents (triggers AI pipeline)"
  freeform_tags  = var.freeform_tags
}

# Email subscription (if provided)
resource "oci_ons_subscription" "email" {
  count          = var.notification_email != "" ? 1 : 0
  compartment_id = var.compartment_ocid
  topic_id       = oci_ons_notification_topic.doc_alerts.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
  freeform_tags  = var.freeform_tags
}

# ----------------------------------------------------------
# OCI Events Rule — Trigger notification on Object Storage upload
# ----------------------------------------------------------
resource "oci_events_rule" "doc_upload_trigger" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.prefix}-doc-upload-event"
  description    = "Triggers notification when a document is uploaded to Object Storage"
  is_enabled     = true

  condition = jsonencode({
    eventType = [
      "com.oraclecloud.objectstorage.createobject",
      "com.oraclecloud.objectstorage.updateobject"
    ]
  })

  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.doc_alerts.id
      description = "Send notification on document upload"
    }
  }

  freeform_tags = var.freeform_tags
}

# ----------------------------------------------------------
# Outputs
# ----------------------------------------------------------
output "queue_id" { value = oci_queue_queue.user_notifications.id }

output "queue_endpoint" {
  value = oci_queue_queue.user_notifications.messages_endpoint
}

output "topic_id" { value = oci_ons_notification_topic.doc_alerts.id }
