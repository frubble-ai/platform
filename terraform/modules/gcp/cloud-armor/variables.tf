variable "project_id" {
  type        = string
  description = "Project that owns the policy."
}

variable "name" {
  type        = string
  description = "Policy name, e.g. `frubble-stg-lb`."
}

variable "description" {
  type        = string
  default     = "WAF for the load balancer"
  description = "Shown in the console."
}

variable "rate_limit" {
  type = object({
    count            = number
    interval_seconds = number
    priority         = optional(number, 1000)
  })
  description = "Requests one client IP may send per interval before it gets 429s. The priority must sort after every WAF rule, or the throttle's allow ends evaluation before they run."
}

variable "waf_rules" {
  type = map(object({
    priority    = number
    sensitivity = optional(number, 1)
    preview     = optional(bool, true)
  }))
  default     = {}
  description = "Preconfigured rule sets by name (e.g. `sqli-v33-stable`). Preview logs matches without blocking; turn it off per rule once the logs show no false positives. Each rule is billed monthly."
}
