# Not secret: an id is what an audit log entry names, and a version name is
# what the worker's secret binding resolves `latest` to.
output "key_ids" {
  value = { for name, key in mailgun_api_key.sending : name => key.id }
}

output "secret_versions" {
  value = { for env, version in google_secret_manager_secret_version.sending_key : env => version.name }
}
