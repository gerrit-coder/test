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

# Variables for Environment Configuration

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

resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-EOT
    #!/bin/sh
    set -e

    # Install code-server if not already installed
    if [ ! -f /home/coder/.local/bin/code-server ]; then
      echo "Installing code-server..."
      curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone
    else
      echo "code-server already installed"
    fi

    # Install git if not already installed
    if ! command -v git >/dev/null 2>&1; then
      echo "Installing git..."
      apt-get update -qq && apt-get install -y -qq git
    else
      echo "git already installed"
    fi

    # Clone Gerrit repository and cherry-pick patchset if parameters are provided
    # These environment variables are passed as rich parameters from the coder-workspace plugin
    if [ -n "$${GERRIT_GIT_HTTP_URL}" ] || [ -n "$${GERRIT_GIT_SSH_URL}" ]; then
      REPO_DIR="$${REPO:-gerrit-repo}"
      GIT_URL="$${GERRIT_GIT_HTTP_URL:-$${GERRIT_GIT_SSH_URL}}"

      echo "Cloning Gerrit repository from $GIT_URL..."

      # Check if repository already exists
      if [ -d "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
        echo "Repository $REPO_DIR already exists. Updating..."
        cd "$REPO_DIR"

        # Fetch the latest changes
        git fetch origin || true

        # If change ref is provided, fetch and cherry-pick it
        if [ -n "$${GERRIT_CHANGE_REF}" ]; then
          echo "Fetching patchset $${GERRIT_CHANGE_REF}..."
          git fetch origin "$${GERRIT_CHANGE_REF}" || {
            echo "Warning: Failed to fetch $${GERRIT_CHANGE_REF}"
          }

          # Check if already cherry-picked
          if ! git log --oneline --grep="Cherry picked from" | grep -q "$${GERRIT_CHANGE_REF}"; then
            echo "Cherry-picking patchset $${GERRIT_CHANGE_REF}..."
            git cherry-pick FETCH_HEAD || {
              echo "Cherry-pick failed. Repository is in cherry-pick state."
              echo "Run 'git status' to see details and resolve conflicts manually."
            }
          else
            echo "Patchset $${GERRIT_CHANGE_REF} already cherry-picked."
          fi
        fi
      else
        # Clone the repository
        git clone "$GIT_URL" "$REPO_DIR" || {
          echo "Error: Failed to clone repository"
          exit 1
        }

        cd "$REPO_DIR"

        # If change ref is provided, fetch and cherry-pick it
        if [ -n "$${GERRIT_CHANGE_REF}" ]; then
          echo "Fetching patchset $${GERRIT_CHANGE_REF}..."
          git fetch origin "$${GERRIT_CHANGE_REF}" || {
            echo "Error: Failed to fetch patchset $${GERRIT_CHANGE_REF}"
            exit 1
          }

          echo "Cherry-picking patchset $${GERRIT_CHANGE_REF}..."
          git cherry-pick FETCH_HEAD || {
            echo "Cherry-pick failed. Repository is in cherry-pick state."
            echo "Run 'git status' to see details and resolve conflicts manually."
          }
        fi

        echo "Repository cloned and ready at: $(pwd)"
        echo "Change: $${GERRIT_CHANGE:-unknown}, Patchset: $${GERRIT_PATCHSET:-unknown}"
      fi

      # Return to home directory
      cd /home/coder
    else
      echo "No Gerrit git repository URL provided. Skipping clone and cherry-pick."
    fi

    # Start code-server in background
    echo "Starting code-server on port 13337..."
    nohup /home/coder/.local/bin/code-server --auth none --port 13337 --bind-addr 0.0.0.0:13337 > /tmp/code-server.log 2>&1 &

    # Wait a moment for code-server to start
    sleep 3

    # Verify code-server is running
    if pgrep -f "code-server" > /dev/null; then
      echo "code-server started successfully"
    else
      echo "Failed to start code-server"
      cat /tmp/code-server.log
    fi
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
  name  = "coder-workspace-${data.coder_workspace.me.name}-${count.index}"
  network_mode = "host"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "CODER_AGENT_URL=${var.coder_access_url}",
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

  # Bootstrap and run the Coder agent; it will execute startup_script above
  command = [
    "sh",
    "-lc",
    <<-EOC
      set -e
      # Install Coder agent and connect back using the provided token
      curl -fsSL https://coder.com/install.sh | sh
      echo "Starting Coder agent..."
      coder agent start --url "$CODER_AGENT_URL" --token "$CODER_AGENT_TOKEN"
    EOC
  ]

  lifecycle {
    create_before_destroy = true
  }
}
