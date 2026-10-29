# Pinned, like everything else in CI: a linter that silently gains rules
# between runs turns a green branch red with no commit to explain it.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

config {
  call_module_type = "local"
}
