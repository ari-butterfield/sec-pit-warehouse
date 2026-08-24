variable "project_id" {
  type        = string
  description = "GCP project ID hosting the warehouse."
}

variable "region" {
  type        = string
  description = "Region for BigQuery datasets and the GCS bucket. Keep both in one region to avoid cross-region query costs."
  default     = "us-central1"
}
