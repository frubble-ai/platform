variable "project_id" {
  type        = string
  description = "Project the instance runs in."
}

variable "name" {
  type        = string
  description = "Instance name, e.g. `frubble-stg-postgres`. Cloud SQL keeps a deleted name reserved for about a week."
}

variable "region" {
  type        = string
  description = "Region of the instance, the same as the workloads that reach it."
}

variable "network_id" {
  type        = string
  description = "VPC the instance gets its private address in. Its private services peering must exist first."
}

variable "tier" {
  type        = string
  default     = "db-f1-micro"
  description = "Machine type. The shared-core default is the smallest Cloud SQL sells and is Enterprise-only."
}

variable "high_availability" {
  type        = bool
  default     = false
  description = "Regional (two zones) instead of zonal. Doubles the compute charge."
}

variable "disk_size_gb" {
  type        = number
  default     = 10
  description = "Initial disk. Autoresize grows it; the size in state is ignored by Cloud SQL once it has grown."
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Daily backups kept, and days of transaction logs for point-in-time recovery."
}

variable "database_name" {
  type        = string
  description = "Name of the one database the application uses."
}

variable "user_name" {
  type        = string
  description = "The application's database user."
}

variable "placeholder_password" {
  type        = string
  default     = "REPLACE_ME_WITH_gcloud_sql_users_set-password"
  description = "Password written at creation and never the real one: whatever Terraform writes is recorded in state."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Refuse `terraform destroy` and console deletion of the instance. Off in stg."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels on the instance."
}
