variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "bucket-logs-to-ydb"
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

variable "s3_bucket" {
  description = "S3 Bucket containing S3 logs."
  type        = string
  default     = "bucket"
}

variable "ydb_table_name" {
  description = "YDB Table name for S3 logs."
  type        = string
  default     = "s3_bucket_logs"
}