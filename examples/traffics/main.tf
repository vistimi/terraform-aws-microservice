module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-container-traffics"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            name = "first"
            docker = {
              repository = {
                name = "ubuntu"
              }
              image = {
                tag = "latest"
              }
            }

            traffics = [
              {
                # this will redirect http:80 to http:80
                listener = {
                  # port is by default 80 with http
                  protocol = "http"
                }
                target = {
                  port              = 80
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              },
              {
                # this will redirect https:444 to http:80
                listener = {
                  port     = 444
                  protocol = "https"
                }
                target = {
                  port              = 80
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              },
              {
                # this will redirect http:81 to http:81
                listener = {
                  port     = 81
                  protocol = "http"
                }
                target = {
                  port              = 81
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              },
            ]

            entrypoint = [
              "/bin/bash",
              "-c",
            ]
            command = [
              "apt update -q > /dev/null 2>&1; apt install apache2 ufw systemctl curl -yq > /dev/null 2>&1; ufw app list; echo -e 'Listen 81' >> /etc/apache2/ports.conf; echo print /etc/apache2/ports.conf.....; cat /etc/apache2/ports.conf; echo -e '<VirtualHost *:81>\nServerAdmin webmaster@localhost\nDocumentRoot /var/www/html\nErrorLog $${APACHE_LOG_DIR}/error.log\nCustomLog $${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>' >> /etc/apache2/sites-enabled/000-default.conf; echo print /etc/apache2/sites-enabled/000-default.conf.....; cat /etc/apache2/sites-enabled/000-default.conf; systemctl start apache2; echo test localhost:: $(curl -s -o /dev/null -w '%%{http_code}' localhost); echo test localhost:81:: $(curl -s -o /dev/null -w '%%{http_code}' localhost:81); sleep infinity",
            ]
            readonly_root_filesystem = false
          }
        ]
        # ...
      }
      # ...
    }
    # ...
  }

  vpc      = {} # ...
  traffics = [] # ...
}
