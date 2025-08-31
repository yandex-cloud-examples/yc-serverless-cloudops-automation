variable "scenario" {
  description = "Scenario name for resource naming"
  type        = string
  default     = "stop-vm"
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

variable "vm_ids" {
  description = "List of VM IDs to start"
  type        = list(string)
  default     = []
}

variable "cron_trigger" {
  description = "Cron trigger for VM stop"
  type        = string
  default     = "0-4 20 ? * * *"
}