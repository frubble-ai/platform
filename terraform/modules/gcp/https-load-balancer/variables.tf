variable "project_id" {
  type        = string
  description = "Project that owns the load balancer."
}

variable "name" {
  type        = string
  description = "Prefix for every resource here, e.g. `frubble-stg`."
}

variable "backends" {
  type = map(object({
    service = string
    region  = string
    host    = string
  }))
  description = "Cloud Run services behind the balancer, keyed by a short name. Each gets a serverless NEG, a backend service, a host rule and a certificate entry for `host`."
}

variable "default_backend" {
  type        = string
  description = "Key in `backends` that answers requests for an unknown host."
}

variable "security_policy" {
  type        = string
  default     = null
  description = "Self link of the Cloud Armor policy attached to every backend service."
}

variable "log_sample_rate" {
  type        = number
  default     = 1
  description = "Fraction of requests the balancer logs."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels on the resources that accept them."
}
