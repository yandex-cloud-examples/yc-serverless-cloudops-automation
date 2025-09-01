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
  description        = "${var.bucket} cloudops-${local.scenario}-${random_string.random.result}"
  runtime            = "python312"
  entrypoint         = "main.handler"
  memory             = "128"
  execution_timeout  = "300"
  service_account_id = yandex_iam_service_account.sa.id

  user_hash = data.archive_file.function.output_base64sha256
  content {
    zip_filename = data.archive_file.function.output_path
  }

  environment = merge(
    {
      S3_BUCKET = var.bucket
    },
    var.key_prefix != "" ? { S3_PREFIX = var.key_prefix } : {}
  )

  secrets {
    id                   = yandex_lockbox_secret.secret-aws.id
    version_id           = yandex_lockbox_secret_version.secret-aws-v1.id
    key                  = "access_key"
    environment_variable = "S3_KEY"
  }

  secrets {
    id                   = yandex_lockbox_secret.secret-aws.id
    version_id           = yandex_lockbox_secret_version.secret-aws-v1.id
    key                  = "secret_key"
    environment_variable = "S3_SECRET"
  }
  depends_on = [yandex_lockbox_secret_iam_member.viewer]
}

# Yandex Cloud Trigger
resource "yandex_function_trigger" "cron" {
  name        = "cloudops-${local.scenario}-${random_string.random.result}"
  description = "${var.bucket} cloudops-${local.scenario}-${random_string.random.result}"
  timer {
    cron_expression = "${var.cron_trigger}"
  }
  function {
    id = yandex_function.main.id
    service_account_id = yandex_iam_service_account.sa-invoker.id
  }
  depends_on = [yandex_function.main]
}

# Service account for the function
resource "yandex_iam_service_account" "sa" {
  folder_id       = var.folder_id
  name            = "cloudops-${local.scenario}-sa-${random_string.random.result}"
  description     = "cloudops-${local.scenario}-sa-${random_string.random.result}"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-storage-editor" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa.id}"
  role            = "storage.editor"
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

# Static key
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "cloudops-${local.scenario}-${random_string.random.result} static key"
}

# Lockbox
resource "yandex_lockbox_secret" "secret-aws" {
  name = "cloudops-${local.scenario}-${random_string.random.result}"
}

resource "yandex_lockbox_secret_version" "secret-aws-v1" {
  secret_id = yandex_lockbox_secret.secret-aws.id
  entries {
    key        = "access_key"
    text_value = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  }
  entries {
    key        = "secret_key"
    text_value = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  }
}

resource "yandex_lockbox_secret_iam_member" "viewer" {
  secret_id = yandex_lockbox_secret.secret-aws.id
  role      = "lockbox.payloadViewer"

  member = "serviceAccount:${yandex_iam_service_account.sa.id}"
}