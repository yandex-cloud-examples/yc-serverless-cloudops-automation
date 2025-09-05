locals {
  scenario = var.scenario
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/function.zip"
}

resource "random_string" "random" {
  length    = 4
  upper     = false
  lower     = true
  numeric   = true
  special   = false
}

# Yandex Cloud Function
resource "yandex_function" "main" {
  folder_id          = var.folder_id
  name               = "cloudops-${local.scenario}-${random_string.random.result}"
  description        = "${var.folder_id}"
  runtime            = "bash-2204"
  entrypoint         = "handler.sh"
  memory             = "128"
  execution_timeout  = "600"
  service_account_id = yandex_iam_service_account.sa.id

  user_hash = data.archive_file.function.output_base64sha256
  content {
    zip_filename = data.archive_file.function.output_path
  }

  environment = {
    AGE_DAYS  = var.snapshot_age_days
    FOLDER_ID = var.folder_id
  }
}

# Yandex Cloud Trigger
resource "yandex_function_trigger" "cron" {
  name        = "cloudops-${local.scenario}-${random_string.random.result}"
  description = "${var.folder_id} cloudops-${local.scenario}-${random_string.random.result}"
  timer {
    cron_expression = "${var.cron_trigger}"
  }
  function {
    id = yandex_function.main.id
    service_account_id = yandex_iam_service_account.sa-invoker.id
  }
  depends_on = [yandex_function.main, yandex_resourcemanager_folder_iam_member.sa-invoker]
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