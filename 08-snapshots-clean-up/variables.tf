variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "snapshots-clean-up"
}

variable "provider_key_file" {
  description = "Path to service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud zone"
  type        = string
  default     = "ru-central1-a"
}

variable "cron_trigger" {
  description = "Cron trigger for snapshot clean-up."
  type        = string
  default     = "0 0 ? * * *"
}

variable "snapshot_age_days" {
  description = "Snapshots age for deletion, in days."
  type        = number
  default     = 30
}