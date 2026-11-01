variable "environment_projects" {
  description = "Project id per environment handle, as org/gcp/_setup takes it; where each sending key's secret lives."
  type        = map(string)
}
