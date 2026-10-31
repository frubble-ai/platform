output "ip_address" {
  description = "The address the hostnames point at."
  value       = google_compute_global_address.this.address
}

output "dns_authorization_records" {
  description = "Per backend, the CNAME that proves control of its host to Certificate Manager. Publish it before the hostname itself."
  value = {
    for key, auth in google_certificate_manager_dns_authorization.this : key => {
      name = auth.dns_resource_record[0].name
      type = auth.dns_resource_record[0].type
      data = auth.dns_resource_record[0].data
    }
  }
}

output "certificate_id" {
  description = "The managed certificate, for checking its state."
  value       = google_certificate_manager_certificate.this.id
}

output "url_map_name" {
  description = "Label the balancer's metrics carry; the alerts filter on it."
  value       = google_compute_url_map.this.name
}
