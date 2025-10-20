terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "docker" {}

data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-EOT
    #!/bin/sh
    set -x
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone
    nohup /home/coder/.local/bin/code-server --auth none --port 13337 > /tmp/code-server.log 2>&1 &
    sleep 2
  EOT
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Web"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace.me.name}"

  env = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  command = ["sh", "-c", coder_agent.main.init_script]
}
