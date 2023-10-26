resource "local_file" "env" {
  content  = var.content
  filename = var.filename
}
