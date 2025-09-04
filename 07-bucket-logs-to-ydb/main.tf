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
  description        = "${var.s3_bucket} cloudops-${local.scenario}-${random_string.random.result}"
  runtime            = "python312"
  entrypoint         = "main.handler"
  memory             = "128"
  execution_timeout  = "600"
  service_account_id = yandex_iam_service_account.sa.id

  user_hash = data.archive_file.function.output_base64sha256
  content {
    zip_filename = data.archive_file.function.output_path
  }

  environment = {
    YDB_ENDPOINT   = "grpcs://ydb.serverless.yandexcloud.net:2135"
    S3_BUCKET      = var.s3_bucket
    S3_ENDPOINT    = "https://storage.yandexcloud.net"
    YDB_DATABASE   = yandex_ydb_database_serverless.db.database_path
    YDB_TABLE_NAME = yandex_ydb_table.s3_bucket_logs.path
  }

  secrets {
    id                   = yandex_lockbox_secret.secret-aws.id
    version_id           = yandex_lockbox_secret_version.secret-aws-v1.id
    key                  = "access_key"
    environment_variable = "AWS_ACCESS_KEY_ID"
  }

  secrets {
    id                   = yandex_lockbox_secret.secret-aws.id
    version_id           = yandex_lockbox_secret_version.secret-aws-v1.id
    key                  = "secret_key"
    environment_variable = "AWS_SECRET_ACCESS_KEY"
  }
  depends_on = [yandex_lockbox_secret_iam_member.viewer]
}

# Yandex Cloud Trigger
resource "yandex_function_trigger" "logging" {
  name        = "cloudops-${local.scenario}-${random_string.random.result}"
  description = "${var.s3_bucket}"

  object_storage {
      bucket_id = var.s3_bucket
      create    = true
      batch_cutoff = 0
      batch_size = 1
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

resource "yandex_resourcemanager_folder_iam_member" "sa-ydb-editor" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa.id}"
  role            = "ydb.editor"
}

resource "yandex_resourcemanager_folder_iam_member" "sa-storage-viewer" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa.id}"
  role            = "storage.viewer"
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

# YDB Serverless
resource "yandex_ydb_database_serverless" "db" {
  name                = "cloudops-${local.scenario}-${random_string.random.result}"
}

# YDB Table
resource "yandex_ydb_table" "s3_bucket_logs" {
  path              = "${var.ydb_table_name}"
  connection_string = yandex_ydb_database_serverless.db.ydb_full_endpoint

  column {
    name     = "timestamp"
    type     = "Timestamp"
    not_null = true
  }

  column {
    name     = "request_id"
    type     = "Utf8"
    not_null = true
  }

  column {
    name     = "bucket"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "handler"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "object_key"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "storage_class"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "requester"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "version_id"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "status"
    type     = "Uint32"
    not_null = false
  }

  column {
    name     = "method"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "protocol"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "scheme"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "http_referer"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "user_agent"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "vhost"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "ip"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "request_path"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "request_args"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "ssl_protocol"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "range"
    type     = "Utf8"
    not_null = false
  }

  column {
    name     = "bytes_send"
    type     = "Uint64"
    not_null = false
  }

  column {
    name     = "bytes_received"
    type     = "Uint64"
    not_null = false
  }

  column {
    name     = "request_time"
    type     = "Uint32"
    not_null = false
  }

  primary_key = ["request_id", "timestamp"]
}
