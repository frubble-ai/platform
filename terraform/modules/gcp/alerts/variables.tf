variable "project_id" {
  type        = string
  description = "Project the policies live in."
}

variable "name" {
  type        = string
  description = "Prefix for display names, e.g. `frubble-stg`."
}

variable "email" {
  type        = string
  description = "Address that receives every alert."
}

variable "service_name" {
  type        = string
  description = "Cloud Run service the latency and saturation policies watch."
}

variable "url_map_name" {
  type        = string
  description = "URL map of the load balancer in front of it; its request metrics carry this label."
}

variable "max_instances" {
  type        = number
  description = "The service's scaling ceiling. Reaching it is the saturation signal."
}

variable "error_ratio" {
  type        = number
  default     = 0.05
  description = "Share of 5xx over all requests, over five minutes, that pages."
}

variable "latency_ms" {
  type        = number
  default     = 2000
  description = "p95 request latency, over fifteen minutes, that pages."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "User labels on the channel and the policies."
}
