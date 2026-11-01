output "instance_name" {
  value = google_sql_database_instance.this.name
}

output "private_ip" {
  description = "Address the workloads connect to, reachable only inside the peered VPC."
  value       = google_sql_database_instance.this.private_ip_address
}

output "server_ca_pem" {
  description = "The instance's CA certificate. Clients pin it; it is public material, not a secret."
  value       = google_sql_database_instance.this.server_ca_cert[0].cert
}

output "database_name" {
  value = google_sql_database.this.name
}

output "user_name" {
  value = google_sql_user.application.name
}
