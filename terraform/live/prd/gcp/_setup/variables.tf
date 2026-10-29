variable "project_id" {
  description = "The stg project. Stated here, verified against the live credential by the pin module."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "management_state_bucket" {
  description = "Bucket holding the org _setup state this root reads its inputs from."
  type        = string
}

variable "environment" {
  type    = string
  default = "prd"
}

variable "management_project_id" {
  description = "Where the bootstrap admin lives. Named so the project pin accepts it applying this root."
  type        = string
}
