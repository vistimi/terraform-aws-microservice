resource "time_sleep" "wait" {
  create_duration = "90s"
}

resource "null_resource" "grpcurl_download" {
  provisioner "local-exec" {
    command = <<EOT
    arch=$(uname -m)
    if [ "$arch" == "aarch64" ]; then 
        arch=arm64; 
    fi
    wget https://github.com/fullstorydev/grpcurl/releases/download/v1.8.7/grpcurl_1.8.7_linux_$arch.tar.gz -q
    tar -xzvf grpcurl_1.8.7_linux_$arch.tar.gz grpcurl
    rm grpcurl_1.8.7_linux_$arch.tar.gz
    EOT
  }

  depends_on = [time_sleep.wait]
}

resource "null_resource" "health_checks" {
  for_each = { for health_check in var.health_checks : join("-", [health_check.adress, health_check.service, health_check.method, health_check.request]) => health_check }

  provisioner "local-exec" {
    command = "./grpcurl -d '${each.value.request}' ${each.value.adress} ${each.value.service}.${each.value.method}"
  }

  depends_on = [null_resource.grpcurl_download]
}

resource "null_resource" "grpcurl_clean" {
  provisioner "local-exec" {
    command = "rm grpcurl"
  }

  depends_on = [null_resource.health_checks]
}
