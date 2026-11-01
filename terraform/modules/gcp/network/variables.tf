variable "project_id" {
  type        = string
  description = "Project the network lives in."
}

variable "name" {
  type        = string
  description = "Network name, e.g. `frubble-stg`."
}

variable "region" {
  type        = string
  description = "Region of the workloads' subnet. Cloud Run direct VPC egress needs a subnet in its own region."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.0.0/24"
  description = "Range of the workloads' subnet. Each Cloud Run instance takes an address from it; /24 is room for far more instances than the services may scale to."
}
