# The zone settings this root used to own moved to org/cloudflare, so they go
# through plan, review and apply.
#
# `removed` with `destroy = false` rather than deleting the resource block:
# deleting it would make Terraform destroy the settings, and destroying a
# cloudflare_zone_setting does not remove anything, it resets that setting to
# Cloudflare's default. `ssl` would drop from strict to flexible on a live
# zone, between this apply and the next one.
removed {
  from = cloudflare_zone_setting.this

  lifecycle {
    destroy = false
  }
}
