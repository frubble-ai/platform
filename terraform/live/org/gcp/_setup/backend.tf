# Kept in its own file because the bootstrap has to run without it.
#
# This root creates the bucket it stores its state in, so on the very first
# apply that bucket does not exist yet. `init -backend=false` does not help:
# it prepares providers but refuses to run an apply. The bootstrap therefore
# moves this file aside, applies onto local state, puts it back, and migrates.
# The README spells out the four commands.
#
# The bucket name is supplied at init rather than written here, for the same
# reason it cannot be a constant: the file that creates a thing cannot also
# hardcode it.
terraform {
  backend "gcs" {
    prefix = "org/gcp/setup"
  }
}
