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
  description        = "${var.logging_group} cloudops-${local.scenario}-${random_string.random.result}"
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
    YDB_DATABASE   = yandex_ydb_database_serverless.db.database_path
    YDB_TABLE_NAME = yandex_ydb_table.load_balancer_requests.path
  }

  secrets {
    id = "${yandex_lockbox_secret.secret-api.id}"
    version_id = "${yandex_lockbox_secret_version.secret-api-v1.id}"
    key = "secret_key"
    environment_variable = "API_KEY"
  }
  depends_on = [yandex_lockbox_secret_iam_member.viewer]
}

# Yandex Cloud Trigger
resource "yandex_function_trigger" "logging" {
  name        = "cloudops-${local.scenario}-${random_string.random.result}"
  description = "${var.logging_group}"

  logging {
     group_id       = "${var.logging_group}"
     
     batch_cutoff   = 10
     batch_size     = 10
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

resource "yandex_resourcemanager_folder_iam_member" "sa-logging-reader" {
  folder_id       = var.folder_id
  member          = "serviceAccount:${yandex_iam_service_account.sa.id}"
  role            = "logging.reader"
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

# API key
resource "yandex_iam_service_account_api_key" "sa-api-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "cloudops-${local.scenario}-${random_string.random.result}"
}

# Lockbox
resource "yandex_lockbox_secret" "secret-api" {
  name = "cloudops-${local.scenario}-${random_string.random.result}"
}

resource "yandex_lockbox_secret_version" "secret-api-v1" {
  secret_id = yandex_lockbox_secret.secret-api.id
  entries {
    key        = "secret_key"
    text_value = yandex_iam_service_account_api_key.sa-api-key.secret_key
  }
}

resource "yandex_lockbox_secret_iam_member" "viewer" {
  secret_id = yandex_lockbox_secret.secret-api.id
  role      = "lockbox.payloadViewer"

  member = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

# YDB Serverless
resource "yandex_ydb_database_serverless" "db" {
  name                = "${var.logging_group}-cloudops-${local.scenario}-${random_string.random.result}"
}

# YDB Table for Load Balancer logs
resource "yandex_ydb_table" "load_balancer_requests" {
  path              = "load_balancer_requests"
  connection_string = yandex_ydb_database_serverless.db.ydb_full_endpoint

  column {
    name     = "request_id"
    type     = "Utf8"
    not_null = true
  }
  
  column {
    name     = "time"
    type     = "Timestamp"
    not_null = true
  }
  
  column {
    name     = "type"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "client_ip"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "backend_ip"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "http_method"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "http_status"
    type     = "Uint32"
    not_null = false
  }
  
  column {
    name     = "request_uri"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "user_agent"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "authority"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "request_time"
    type     = "Double"
    not_null = false
  }
  
  column {
    name     = "backend_processing_time"
    type     = "Double"
    not_null = false
  }
  
  column {
    name     = "request_body_bytes"
    type     = "Uint64"
    not_null = false
  }
  
  column {
    name     = "response_body_bytes"
    type     = "Uint64"
    not_null = false
  }
  
  column {
    name     = "load_balancer_id"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "backend_name"
    type     = "Utf8"
    not_null = false
  }
  
  column {
    name     = "route_name"
    type     = "Utf8"
    not_null = false
  }

  primary_key = ["request_id", "time"]
}
