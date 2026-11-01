variable "environment" {
  type        = string
  description = "`stg` or `prd`."

  validation {
    condition     = contains(["stg", "prd"], var.environment)
    error_message = "environment must be stg or prd."
  }
}

variable "zone" {
  type        = string
  description = "The DNS zone every hostname is under, e.g. `frubble.ai`."
}
