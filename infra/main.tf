terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Landing zone for raw SEC quarterly files as Parquet, before BigQuery load.
resource "google_storage_bucket" "raw" {
  name                        = "${var.project_id}-sec-raw"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

# Raw landing dataset: dlt writes here, dbt sources read from here.
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = "sec_raw"
  location                   = var.region
  description                = "Raw SEC Financial Statement Data Sets, loaded by dlt."
  delete_contents_on_destroy = true
}

# dbt writes its three layers here.
resource "google_bigquery_dataset" "analytics" {
  dataset_id                 = "sec_analytics"
  location                   = var.region
  description                = "dbt-managed staging/intermediate/marts layers."
  delete_contents_on_destroy = true
}

resource "google_service_account" "pipeline" {
  account_id   = "sec-pipeline"
  display_name = "SEC PIT warehouse pipeline (dlt + dbt)"
}

resource "google_project_iam_member" "pipeline_bq" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_storage_bucket_iam_member" "pipeline_gcs" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_service_account_key" "pipeline" {
  service_account_id = google_service_account.pipeline.name
}

# Written to disk locally, gitignored. See docs/architecture.md for why a key
# and not Workload Identity Federation in v1.
resource "local_file" "pipeline_key" {
  filename        = "${path.module}/.secrets/sec-pipeline-sa.json"
  content         = base64decode(google_service_account_key.pipeline.private_key)
  file_permission = "0600"
}

resource "google_storage_bucket_iam_member" "pipeline_gcs_bucket_read" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.pipeline.email}"
}
