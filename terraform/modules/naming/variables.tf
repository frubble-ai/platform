variable "environment" {
  type        = string
  description = "`dev`, `stg` or `prd`."

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "environment must be dev, stg or prd."
  }
}

variable "zone" {
  type        = string
  description = "The DNS zone every hostname is under, e.g. `frubble.ai`."
}
