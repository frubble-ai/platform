variable "project_id" {
  type        = string
  description = "Project the service runs in."
}

variable "name" {
  type        = string
  description = "Service name, e.g. `frubble-stg-api`."
}

variable "region" {
  type        = string
  description = "Region of the service. The load balancer's serverless NEG must be in the same one."
}

variable "service_account_email" {
  type        = string
  description = "Identity the revisions run as. Created in the environment's `_setup` root."
}

variable "image" {
  type        = string
  description = "Image for the first revision only. CI replaces it on every deploy and Terraform ignores the change."
}

variable "port" {
  type        = number
  default     = 8080
  description = "Container port the application listens on."
}

variable "health_path" {
  type        = string
  default     = "/health"
  description = "Path the startup and liveness probes GET."
}

variable "command" {
  type        = list(string)
  default     = null
  description = "Entrypoint override. Null keeps the image's; the worker runs the same image with its own."
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
  description = "Environment variables read from Secret Manager when an instance starts, keyed by variable name. The service's identity needs accessor on each secret, or the revision refuses to start."
}

variable "vpc" {
  type = object({
    network    = string
    subnetwork = string
  })
  default     = null
  description = "Direct VPC egress for private addresses, such as the database's. Null keeps the service off the VPC."
}

variable "cpu" {
  type        = string
  default     = "1"
  description = "vCPU limit. Below 1 needs request-based billing and gen1, which is the default here."
}

variable "memory" {
  type        = string
  default     = "512Mi"
  description = "Memory limit."
}

variable "min_instances" {
  type        = number
  default     = 0
  description = "Instances kept warm. 0 scales to zero; 1 trades a cold start for an idle charge."
}

variable "max_instances" {
  type        = number
  default     = 3
  description = "Ceiling on instances, and the number the alert on saturation compares against."
}

variable "concurrency" {
  type        = number
  default     = 80
  description = "Requests one instance serves at once."
}

variable "timeout_seconds" {
  type        = number
  default     = 60
  description = "Request timeout."
}

variable "startup_cpu_boost" {
  type        = bool
  default     = true
  description = "Extra CPU while an instance starts, free in steady state."
}

variable "execution_environment" {
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN1"
  description = "gen1 starts faster and allows less than 512 MiB; gen2 is for sustained CPU."
}

variable "default_uri_disabled" {
  type        = bool
  default     = true
  description = "No run.app URL. Same-project callers such as Cloud Scheduler can otherwise reach it under internal ingress, around the load balancer and its WAF."
}

variable "ingress" {
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  description = "Who may reach the service. The default admits Google load balancers and this project's VPC networks, not the internet."
}

variable "invoker_iam_disabled" {
  type        = bool
  default     = true
  description = "Skip the invoker IAM check. An external load balancer carries no invoker identity, and the org policy forbids an allUsers binding; the missing run.app URL and `ingress` are what limit the callers."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Refuse `terraform destroy` on the service. Off in stg."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels on the service and its revisions."
}
