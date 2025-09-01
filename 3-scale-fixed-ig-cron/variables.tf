variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "scale-ig"
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

variable "ig_ids" {
  description = "List of Instance Group IDs to scale."
  type        = list(string)
  default     = []
}

variable "cron_scale_up" {
  description = "Cron trigger for Instance Group scale up."
  type        = string
  default     = "0-2 8 ? * * *"
}

variable "cron_scale_down" {
  description = "Cron trigger for Instance Group scale down."
  type        = string
  default     = "0-2 8 ? * * *"
}

variable "instances_min" {
  description = "Minimum number of instances in a group."
  type        = number
  default     = 1
}

variable "instances_max" {
  description = "Maximum number of instances in a group."
  type        = number
  default     = 5
}