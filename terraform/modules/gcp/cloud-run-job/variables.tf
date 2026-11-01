variable "project_id" {
  type        = string
  description = "Project the job runs in."
}

variable "name" {
  type        = string
  description = "Job name, e.g. `frubble-stg-migrate`."
}

variable "region" {
  type        = string
  description = "Region of the job."
}

variable "service_account_email" {
  type        = string
  description = "Identity the executions run as. Created in the environment's `_setup` root."
}

variable "image" {
  type        = string
  description = "Image until the first deploy replaces it. Terraform ignores the change."
}

variable "command" {
  type        = list(string)
  default     = null
  description = "Entrypoint override, e.g. `[\"bun\", \"run\", \"scripts/migrate.ts\"]`. Null keeps the image's."
}

variable "args" {
  type        = list(string)
  default     = null
  description = "Arguments to the entrypoint."
}

variable "env" {
  type        = map(string)
  default     = {}
  description = "Plain environment variables. Secrets go in `secret_env`."
}

variable "secret_env" {
  type = map(object({
    secret  = string
    version = optional(string, "latest")
  }))
  default     = {}
  description = "Environment variables read from Secret Manager at start, keyed by variable name. The job's identity needs accessor on each secret."
}

variable "vpc" {
  type = object({
    network    = string
    subnetwork = string
  })
  default     = null
  description = "Direct VPC egress for private addresses, such as the database's. Null keeps the job off the VPC."
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "timeout_seconds" {
  type        = number
  default     = 600
  description = "How long one execution may run."
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
