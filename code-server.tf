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

# Variables for CORS Configuration and Environment Variables
variable "coder_cors_allow_origins" {
  description = "CORS allowed origins for Gerrit integration"
  type        = string
  default     = "http://127.0.0.1:8080"
}

variable "coder_cors_allow_methods" {
  description = "CORS allowed HTTP methods"
  type        = string
  default     = "GET,POST,DELETE,OPTIONS"
}

variable "coder_cors_allow_headers" {
  description = "CORS allowed headers"
  type        = string
  default     = "Content-Type,Coder-Session-Token,Authorization,Accept"
}

variable "coder_cors_allow_credentials" {
  description = "CORS allow credentials"
  type        = string
  default     = "true"
}

variable "coder_http_address" {
  description = "Coder HTTP server address"
  type        = string
  default     = "0.0.0.0:3000"
}

variable "coder_access_url" {
  description = "Coder access URL"
  type        = string
  default     = "http://127.0.0.1:3000"
}

variable "coder_tls_enable" {
  description = "Enable TLS for Coder server"
  type        = string
  default     = "false"
}

variable "coder_redirect_to_access_url" {
  description = "Redirect to access URL"
  type        = string
  default     = "false"
}

variable "gerrit_url" {
  description = "Gerrit server URL"
  type        = string
  default     = "http://127.0.0.1:8080"
}

variable "coder_port" {
  description = "Coder server port"
  type        = string
  default     = "3000"
}

variable "coder_session_token" {
  description = "Coder session token for API access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "docker_group" {
  description = "Docker group ID for container permissions"
  type        = string
  default     = ""
}

variable "coder_data" {
  description = "Coder data directory path"
  type        = string
  default     = "./coder-data"
}

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

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # CORS Configuration for Gerrit Integration
    "CODER_CORS_ALLOW_ORIGINS=${var.coder_cors_allow_origins}",
    "CODER_CORS_ALLOW_METHODS=${var.coder_cors_allow_methods}",
    "CODER_CORS_ALLOW_HEADERS=${var.coder_cors_allow_headers}",
    "CODER_CORS_ALLOW_CREDENTIALS=${var.coder_cors_allow_credentials}",
    # Server Configuration
    "CODER_HTTP_ADDRESS=${var.coder_http_address}",
    "CODER_ACCESS_URL=${var.coder_access_url}",
    "CODER_TLS_ENABLE=${var.coder_tls_enable}",
    "CODER_REDIRECT_TO_ACCESS_URL=${var.coder_redirect_to_access_url}",
    # Additional Environment Variables
    "GERRIT_URL=${var.gerrit_url}",
    "CODER_PORT=${var.coder_port}",
    "CODER_SESSION_TOKEN=${var.coder_session_token}"
  ]

  command = ["sh", "-c", <<-EOT
    #!/bin/sh
    set -x
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone
    nohup /home/coder/.local/bin/code-server --auth none --port 13337 > /tmp/code-server.log 2>&1 &
    sleep 2
  EOT
  ]
}
