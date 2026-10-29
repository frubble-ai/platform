variable "name" {
  description = "Bucket name. Globally unique across GCS, so prefix it with the project id."
  type        = string
}

variable "project_id" {
  description = "Project that owns the bucket, its key ring and its key."
  type        = string
}

variable "location" {
  description = "Bucket location. The key ring is created in the same location so the key and the data it protects share a failure domain."
  type        = string
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "noncurrent_version_retention_days" {
  description = "How long a superseded state version is kept. Terraform needs old versions to recover from a bad apply; keeping them forever turns the bucket into an unbounded archive of secrets."
  type        = number
  default     = 90
}

variable "abort_incomplete_upload_days" {
  description = "How long an unfinished resumable upload is kept before GCS reclaims it. Interrupted state writes otherwise accrue as billable, invisible garbage."
  type        = number
  default     = 7
}

variable "key_rotation_days" {
  description = "How often the key mints a new primary version."
  type        = number
  default     = 30
}

variable "key_destroy_delay_days" {
  description = "Grace period between scheduling a key version for destruction and it becoming unrecoverable. This is the window in which a mistaken destroy can still be undone; past it, every state file the version encrypted is unreadable forever."
  type        = number
  default     = 30
}
