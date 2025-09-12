data "exoscale_template" "template" {
  zone = var.zone
  name = var.template_name
}

data "ct_config" "ollama" {
  strict       = true
  pretty_print = true
  snippets     = []
  content = yamlencode(
    {
      variant = "fcos"
      version = "1.5.0"
      passwd = {
        users = [
          {
            name                = "core"
            ssh_authorized_keys = [var.ssh_key.public_key]
          }
        ]
      }
      # systemd = {
      #   units = [
      #     { 
      #       name     = "install-ramalama.service"
      #       enabled  = true
      #       contents = <<EOH
      #       [Unit]
      #       Description=Install Ramalama
      #       Wants=network-online.target
      #       After=network-online.target

      #       [Service]
      #       Type=oneshot
      #       ExecStart=rpm-ostree install --idempotent ramalama
      #       ExecStart=/usr/bin/systemctl reboot
      #       RemainAfterExit=yes

      #       [Install]
      #       WantedBy=multi-user.target
      #     EOH
      #     }
      #   ]
      # }
      storage = {
        files = [
          {
            path = "/etc/containers/systemd/ollama.container"
            # mode = 0644
            contents = {
              inline = <<-EOT
              [Container]
              ContainerName=ollama
              HostName=ollama
              Image=docker.io/ollama/ollama
              AutoUpdate=registry
              Volume=/opt/ollama:/root/.ollama
              PublishPort=11434:11434
              # AddDevice=nvidia.com/gpu=all

              [Unit]
              Description=Ollama Service
              After=network.target
              Wants=network.target

              [Service]
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOT
            }
          },
          {
            path = "/usr/local/bin/ollama"
            # mode = 0755
            contents = {
              inline = <<-EOT
              #!/bin/bash
              podman exec -it ollama ollama "$@"
              EOT
            }
          }
        ]
      }
    }
  )
}

resource "exoscale_compute_instance" "ai-runner" {
  name               = "ai-runner"
  zone               = var.zone
  type               = "gpu2.medium"
  disk_size          = 100
  template_id        = data.exoscale_template.template.id
  security_group_ids = [exoscale_security_group.ai-runner.id]
  ssh_keys           = [var.ssh_key.name]

  user_data = data.ct_config.ollama.rendered
}

resource "exoscale_security_group" "ai-runner" {
  name = "ai-runner"
}

resource "exoscale_security_group_rule" "ai-runner_ssh" {
  security_group_id = exoscale_security_group.ai-runner.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 22
  end_port          = 22
}
