variable "project_id" {
  type        = string
  description = "Project the topics live in."
}

variable "name" {
  type        = string
  description = "Topic name, e.g. `frubble-stg-emails`. The subscriptions and the dead-letter topic derive from it."
}

variable "push_endpoint" {
  type        = string
  description = "Where each message is posted: the worker service's URL and the channel's path."
}

variable "push_service_account_email" {
  type        = string
  description = "Identity the push presents, as an OIDC token. The worker service grants it the invoker role."
}

variable "publisher_member" {
  type        = string
  description = "Who may publish, as an IAM member: the API's identity."
}

variable "service_agent_member" {
  type        = string
  description = "Pub/Sub's service agent for the project, as an IAM member. It does the dead-lettering."
}

variable "ack_deadline_seconds" {
  type        = number
  default     = 30
  description = "How long the worker has to answer a push."
}

variable "max_delivery_attempts" {
  type        = number
  default     = 5
  description = "Pushes refused before a message is dead-lettered. 5 is the least Pub/Sub accepts."
}

variable "retention_days" {
  type        = number
  default     = 14
  description = "How long an unacknowledged message waits, on the queue and on the dead-letter subscription."
}

variable "labels" {
  type    = map(string)
  default = {}
}
