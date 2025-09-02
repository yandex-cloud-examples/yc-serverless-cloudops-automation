variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "copy-objects"
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

variable "source_bucket" {
  description = "Source bucket to copy objects from."
  type        = string
  default     = "bucket"
}

variable "target_bucket" {
  description = "Source bucket to copy objects to."
  type        = string
  default     = "bucket"
}