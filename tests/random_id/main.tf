resource "random_id" "generator" {
  keepers = {
    first = "${timestamp()}"
  }
  byte_length = var.byte_length
}
