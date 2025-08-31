terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "~> 0.155"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.provider_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
