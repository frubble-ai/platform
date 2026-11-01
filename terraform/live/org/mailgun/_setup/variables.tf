variable "sending_domains" {
  description = "Sending domain per environment handle, e.g. { stg = \"stg.frubble.ai\" }. Empty until the environment's mailgun root has created the domain."
  type        = map(string)
  default     = {}
}
