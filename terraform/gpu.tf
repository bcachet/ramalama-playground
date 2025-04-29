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
      version = "1.1.0"
      passwd = {
        users = [
          { name                = "core"
            ssh_authorized_keys = [var.ssh_key.public_key]
          }
        ]
      }
      systemd = {
        units = [
          { name     = "ollama.service"
            enabled  = true
            contents = <<EOH
            [Unit]
            Description=Ollama

            [Service]
            Type=simple
            TimeoutSec=600
            ExecStart=podman run --rm --replace --network=host --volume ollama:/root/.ollama --name ollama docker.io/ollama/ollama
            Restart=on-failure

            [Install]
            WantedBy=multi-user.target
          EOH
          },
          {
            name     = "open-webui.service"
            enabled  = true
            contents = <<EOH
            [Unit]
            Description=Open Webui
            After=ollama.service

            [Service]
            Type=simple
            TimeoutSec=600
            ExecStart=podman run --rm --replace --network=host --env OLLAMA_BASE_URL=http://0.0.0.0:11434 --volume open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui
            Restart=on-failure

            [Install]
            WantedBy=multi-user.target
          EOH
          },
          { name     = "deepseek-coder.service"
            enabled  = true
            contents = <<EOH
            [Unit]
            Description=Deepseek model
            After=ollama.service

            [Service]
            Type=oneshot
            TimeoutSec=600
            ExecStart=podman exec -ti ollama ollama pull deepseek-coder
            Restart=on-failure

            [Install]
            WantedBy=multi-user.target
          EOH
        }]
      }
    }
  )
}

resource "exoscale_compute_instance" "vault" {
  name               = "ai-runner"
  zone               = var.zone
  type               = "gpu3.medium"
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

resource "exoscale_security_group_rule" "ai-runner_api" {
  security_group_id = exoscale_security_group.ai-runner.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 11434
  end_port          = 11434
}

resource "exoscale_security_group_rule" "ai-runner_ui" {
  security_group_id = exoscale_security_group.ai-runner.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 8080
  end_port          = 8080
}
