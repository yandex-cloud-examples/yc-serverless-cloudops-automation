variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "bucket-clean-up"
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

variable "bucket" {
  description = "Object Storage bucket for clean-up."
  type        = string
  default     = "bucket-name"
}

variable "key_prefix" {
  description = "Key prefix of objects to be deleted."
  type        = string
  default     = ""
}

variable "cron_trigger" {
  description = "Cron trigger for bucket clean up."
  type        = string
  default     = "0-4 8 ? * * *"
}