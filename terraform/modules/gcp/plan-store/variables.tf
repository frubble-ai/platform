variable "name" {
  description = "Bucket name. Globally unique across GCS, so prefix it with the project id."
  type        = string
}

variable "project_id" {
  description = "Project that owns the bucket, its key ring and its key."
  type        = string
}

variable "location" {
  description = "Bucket and key ring location."
  type        = string
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "retention_days" {
  description = "Days a plan or apply record is kept before GCS deletes it."
  type        = number
  default     = 30
}

variable "key_rotation_days" {
  description = "How often the key mints a new primary version."
  type        = number
  default     = 30
}
