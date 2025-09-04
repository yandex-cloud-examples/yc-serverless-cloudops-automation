# Yandex Cloud Serverless CloudOps Automation

Данный репозиторий содержит Terraform модули и примеры с кодом для автоматизации основных задачи управления облачной инфраструктурой.
Код может использоваться сам по себе, либо в составе Terraform модуля, который разворачивает необходимые, в зависимости от сценария ресурсы: [Cloud Function](https://yandex.cloud/ru/services/functions), [триггеры](https://yandex.cloud/ru/docs/functions/concepts/trigger/), [Yandex Database](https://yandex.cloud/ru/services/ydb).

## Доступные автоматизации

| Функция | Каталог | Описание | Сценарий |
|----------|-----------|-------------|----------|
| **Запуск ВМ по таймеру** | `01-start-vm-cron` | Автоматический запуск ВМ по расписанию | Запуск тестовых ВМ каждое утро в 08:00 |
| **Остановка ВМ по таймеру** | `02-stop-vm-cron` | Автоматическая остановка ВМ по расписанию | Остановка тестовым ВМ каждый вечер в 20:00 |
| **Масштабирование группы узлов** | `03-scale-fixed-ig-cron` | Масштабирование группы узлов по расписанию | Наращивание группы узлов по утрам, уменьшение группы узлов по вечерам |
| **Очистка бакета** | `04-bucket-clean-up` | Автоматическая очистка бакетов по расписанию | Удаление старых бэкапов или временных файлов по заданному расписанию |
| **Копирование объектов бакета** | `05-auto-copy-bucket-objects` | Автоматическое копирование новых объектов между бакетами Object Storage. [Практическое руководство](https://yandex.cloud/en/docs/functions/tutorials/bucket-to-bucket). | Постоянная репликация между бакетами для резервного копирования |
| **Сохранение логов ALB в YDB** | `06-alb-logging-to-ydb` | Сохранение логов Application Load Balancer в YDB. [Практическое руководство для PostgreSQL](https://yandex.cloud/ru/docs/functions/tutorials/logging) | Долговременное хранение логов ALB, анализ логов |
| **Сохранение логов S3 в YDB** | `07-bucket-logs-to-ydb` | Сохранение логов бакета Object Storage в YDB | Долговременное хранение логов доступа к бакету, анализ логов |

## Быстрый старт

1. Склонируйте репозиторий:
    ```bash
    git clone https://github.com/yandex-cloud-examples/yc-serverless-cloudops-automation.git
    cd yc-serverless-cloudops-automation
    ```

2. Выберите сценарий и перейдите в нужный каталог:

    ```bash
    cd 01-start-vm-cron
    ```

3. Скопируйте и заполните переменные:

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    # Edit terraform.tfvars with your values
    ```

 4. Разверните при помощи Terraform:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

 5. Удалить можно следующей командой:

    ```bash
    terraform destroy
    ```

## Пререквизиты

* Установленный и настроенный [Yandex Cloud CLI (yc)](https://yandex.cloud/ru/docs/cli/operations/install-cli) 
* Установленный [Terraform](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart)
* [Авторизованный ключ](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-authorized-keys#console_1) [сервисного аккаунта](https://yandex.cloud/ru/docs/iam/operations/sa/create), с необходимыми ролями в каталоге (например, `admin`), для создания ресурсов в Yandex Cloud

## Настройка

Каждый сценарий содержит следующий набор файлов:

* `variables.tf` - Входные переменные
* `terraform.tfvars.example` - Пример файла конфигурации для переменных
* `main.tf` - Описание создаваемых ресурсов
* `src/` - Код, используемый в функции
* `versions.tf` - Конфигурация провайдера

Все сценарии содержат следующие параметры конфигурации провайдера:

* `provider_key_file` - путь до авторизованного ключа сервисного аккаунта, созданного ранее
* `cloud_id` - Идентификатор [облака](https://yandex.cloud/ru/docs/resource-manager/operations/cloud/get-id)
* `folder_id` - Идентификатор [каталога](https://yandex.cloud/ru/docs/resource-manager/operations/folder/get-id)
* `zone` - Зона доступности (по умолчанию, `ru-central1-a`)
