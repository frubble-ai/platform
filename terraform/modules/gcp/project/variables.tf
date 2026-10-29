variable "project_id" {
  description = "Globally unique project id. This is the hard wall between environments, so it is stated explicitly rather than generated."
  type        = string
}

variable "name" {
  description = "Human-readable project name shown in the console."
  type        = string
}

variable "org_id" {
  description = "Organization the project belongs to."
  type        = string
}

variable "billing_account" {
  description = "Billing account to attach. Without it the APIs below fail to enable, with an error that does not mention billing."
  type        = string
}

variable "apis" {
  description = "APIs to enable. Enabling is idempotent but not instant; dependent resources in the same apply can race a service that is still activating."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels applied to the project."
  type        = map(string)
  default     = {}
}
