# Yandex Cloud Serverless CloudOpsAutomation

This repository contains Terraform modules for automating common cloud operations tasks in Yandex Cloud using Cloud Functions and scheduled triggers.

## Available automations

| Function | Directory | Description | Use Case |
|----------|-----------|-------------|----------|
| **Start VM Cron** | `01-start-vm-cron` | Automatically starts specified virtual machines on a schedule | Start development/testing VMs every morning at 8:00 AM |
| **Stop VM Cron** | `02-stop-vm-cron` | Automatically stops specified virtual machines on a schedule | Stop development/testing VMs every evening at 8:00 PM to save costs |
| **Scale Instance Groups** | `03-scale-fixed-ig-cron` | Automatically scales Yandex Cloud Instance Groups up and down on schedule | Scale production workloads up during business hours and down during nights/weekends |
| **Bucket Clean Up** | `04-bucket-clean-up` | Automatically deletes objects from Object Storage buckets based on key prefix | Clean up temporary files, logs, or old backups on schedule |
| **Auto Copy Bucket Objects** | `05-auto-copy-bucket-objects` | Automatically copies objects between Object Storage buckets. [Tutorial is also available](https://yandex.cloud/en/docs/functions/tutorials/bucket-to-bucket). | Backup important data or sync buckets on schedule |
| **ALB Logs to YDB** | `06-alb-logging-to-ydb` | Automatically processes Cloud Logging messages from ALB and stores them in YDB for analysis. [Tutorial for PostgreSQL is available](https://yandex.cloud/en/docs/functions/tutorials/logging) | Store and analyze load balancer logs in a structured database |
| **S3 Logs to YDB** | `07-bucket-logs-to-ydb` | Automatically processes S3 bucket access logs and stores them in YDB for analysis | Store and analyze S3 bucket access patterns, monitor usage, and track requests in a structured database |

## Quick Start

1. **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd yandex-cloudops-functions
    ```

2. Choose a scenario and navigate to its directory:

    ```bash
    cd 1-start-vm-cron
    ```

3. Copy and configure variables:

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    # Edit terraform.tfvars with your values
    ```

 4. Deploy with Terraform:

    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

 5. Clean up when done:

    ```bash
    terraform destroy
    ```

## Prerequisites

* [Yandex Cloud CLI (yc)](https://yandex.cloud/en/docs/cli/operations/install-cli) installed and configured
* Terraform
* [Service account authorized key file](https://yandex.cloud/en/docs/iam/operations/authentication/manage-authorized-keys#console_1) for Yandex Cloud

## Configuration

Each scenario includes:

* `variables.tf` - Input variables
* `terraform.tfvars.example` - Example configuration
* `main.tf` - Terraform resources
* `src/` - Function source code
* `versions.tf` - Provider requirements

All scenarios share this common provider configuration:

* `provider_key_file` - Path to service account key file
* `cloud_id` - Yandex Cloud ID
* `folder_id` - Yandex Cloud folder ID
* `zone` - Yandex Cloud availability zone (default: `ru-central1-a`)
