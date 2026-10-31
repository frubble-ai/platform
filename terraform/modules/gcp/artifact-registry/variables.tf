variable "project_id" {
  type        = string
  description = "Project that owns the repository."
}

variable "name" {
  type        = string
  description = "Repository id, e.g. `frubble-stg`."
}

variable "location" {
  type        = string
  description = "Region. Keep it the same as the VM's: a cross-region pull is billed as egress and is slower on every boot."
}

variable "description" {
  type        = string
  description = "Shown in the console."
}

variable "keep_recent_versions" {
  type        = number
  default     = 10
  description = "How many image versions survive cleanup; every older one is deleted. Images are rebuilt on every deploy, so an unbounded registry grows without anyone noticing until it leaves the free tier."
}

variable "immutable_tags" {
  type        = bool
  default     = true
  description = "Refuse to move a tag once pushed. CI tags images by commit, so this only bites a push that repeats one."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the repository."
}
