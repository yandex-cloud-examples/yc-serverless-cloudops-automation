locals {
  scenario = var.scenario
}

resource "local_file" "vm_list" {
  content  = join("\n", var.ig_ids)
  filename = "${path.module}/src/igs.txt"
}

# Code file
data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/function.zip"

  depends_on = [local_file.vm_list]
}

# Random
resource "random_string" "random" {
  length    = 4
  upper     = false
  lower     = true
  numeric   = true
  special   = false
}

# Yandex Cloud Function
resource "yandex_function" "scale-up" {
  folder_id          = var.folder_id
  name               = "cloudops-${local.scenario}-up-${random_string.random.result}"
  runtime            = "bash-2204"
  entrypoint         = "handler.sh"
  memory             = "128"
  execution_timeout  = "120"
  service_account_id = yandex_iam_service_account.sa.id

  user_hash = data.archive_file.function.output_base64sha256
  content {
    zip_filename = data.archive_file.function.output_path
  }

  environment = {
    SCALE     = var.instances_max
  }
}

resource "yandex_function" "scale-down" {
  folder_id          = var.folder_id
  name               = "cloudops-${local.scenario}-down-${random_string.random.result}"
  runtime            = "bash-2204"
  entrypoint         = "handler.sh"
  memory             = "128"
  execution_timeout  = "120"
  service_account_id = yandex_iam_service_account.sa.id

  user_hash = data.archive_file.function.output_base64sha256
  content {
    zip_filename = data.archive_file.function.output_path
  }

   environment = {
    SCALE     = var.instances_min
  }
}

# Yandex Cloud Trigger
resource "yandex_function_trigger" "cron-up" {
  name        = "cloudops-${local.scenario}-up-${random_string.random.result}"
  description = "cloudops-${local.scenario}-${random_string.random.result}"
  timer {
    cron_expression = "${var.cron_scale_up}"
  }
  function {
    id = yandex_function.scale-up.id
    service_account_id = yandex_iam_service_account.sa-invoker.id
  }
}

resource "yandex_function_trigger" "cron-down" {
  name        = "cloudops-${local.scenario}-down-${random_string.random.result}"
  description = "cloudops-${local.scenario}-${random_string.random.result}"
  timer {
    cron_expression = "${var.cron_scale_down}"
  }
  function {
    id = yandex_function.scale-down.id
    service_account_id = yandex_iam_service_account.sa-invoker.id
  }
}

# Service account for the function
resource "yandex_iam_service_account" "sa" {
  folder_id       = var.folder_id
  name            = "cloudops-${local.scenario}-sa-${random_string.random.result}"
  description     = "cloudops-${local.scenario}-sa-${random_string.random.result}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-compute-editor" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa.id}"
  role            = "compute.editor"
}

# Create service account for the trigger
resource "yandex_iam_service_account" "sa-invoker" {
  folder_id       = var.folder_id
  name            = "cloudops-${local.scenario}-invoker-${random_string.random.result}"
  description     = "cloudops-${local.scenario}-invoker-${random_string.random.result}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-invoker" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa-invoker.id}"
  role            = "functions.functionInvoker"
}