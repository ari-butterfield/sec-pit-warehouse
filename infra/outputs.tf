output "raw_bucket" {
  value = google_storage_bucket.raw.name
}

output "raw_dataset" {
  value = google_bigquery_dataset.raw.dataset_id
}

output "analytics_dataset" {
  value = google_bigquery_dataset.analytics.dataset_id
}

output "service_account_email" {
  value = google_service_account.pipeline.email
}
