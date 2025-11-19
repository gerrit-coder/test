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

# Rich parameters from coder-workspace plugin
# These are accessed via data sources, not variables
data "coder_parameter" "gerrit_git_http_url" {
  name        = "GERRIT_GIT_HTTP_URL"
  description = "Gerrit git repository HTTP URL"
  type        = "string"
  default     = ""
  mutable     = false
}

data "coder_parameter" "gerrit_git_ssh_url" {
  name        = "GERRIT_GIT_SSH_URL"
  description = "Gerrit git repository SSH URL"
  type        = "string"
  default     = ""
  mutable     = false
}

data "coder_parameter" "gerrit_change_ref" {
  name        = "GERRIT_CHANGE_REF"
  description = "Gerrit change ref for patchset"
  type        = "string"
  default     = ""
  mutable     = false
}

data "coder_parameter" "gerrit_change" {
  name        = "GERRIT_CHANGE"
  description = "Gerrit change number"
  type        = "string"
  default     = ""
  mutable     = false
}

data "coder_parameter" "gerrit_patchset" {
  name        = "GERRIT_PATCHSET"
  description = "Gerrit patchset number"
  type        = "string"
  default     = ""
  mutable     = false
}

data "coder_parameter" "repo" {
  name        = "REPO"
  description = "Repository directory name"
  type        = "string"
  default     = ""
  mutable     = false
}

resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  env = {
    GERRIT_GIT_HTTP_URL = data.coder_parameter.gerrit_git_http_url.value
    GERRIT_GIT_SSH_URL  = data.coder_parameter.gerrit_git_ssh_url.value
    GERRIT_CHANGE_REF   = data.coder_parameter.gerrit_change_ref.value
    GERRIT_CHANGE       = data.coder_parameter.gerrit_change.value
    GERRIT_PATCHSET     = data.coder_parameter.gerrit_patchset.value
    REPO                = data.coder_parameter.repo.value
  }
  startup_script = <<-EOT
    #!/bin/sh
    set -e

    # Debug: Print environment variables for troubleshooting
    echo "=== Debug: Gerrit Environment Variables ==="
    echo "GERRIT_GIT_HTTP_URL: $${GERRIT_GIT_HTTP_URL:-<not set>}"
    echo "GERRIT_GIT_SSH_URL: $${GERRIT_GIT_SSH_URL:-<not set>}"
    echo "GERRIT_CHANGE_REF: $${GERRIT_CHANGE_REF:-<not set>}"
    echo "GERRIT_CHANGE: $${GERRIT_CHANGE:-<not set>}"
    echo "GERRIT_PATCHSET: $${GERRIT_PATCHSET:-<not set>}"
    echo "REPO: $${REPO:-<not set>}"
    echo "============================================"

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

    # Configure git to not use Coder's askpass for Gerrit URLs
    # This prevents authentication errors when cloning from Gerrit
    git config --global credential.helper ""
    # Disable Coder's askpass for Gerrit URLs
    if [ -n "$$GIT_ASKPASS" ]; then
      unset GIT_ASKPASS
    fi
    export GIT_ASKPASS=""

    # Clone Gerrit repository and cherry-pick patchset if parameters are provided
    # These environment variables are passed as rich parameters from the coder-workspace plugin
    if [ -n "$${GERRIT_GIT_HTTP_URL}" ] || [ -n "$${GERRIT_GIT_SSH_URL}" ]; then
      REPO_DIR="$${REPO:-gerrit-repo}"

      # Prefer SSH URL if available (doesn't require authentication)
      if [ -n "$${GERRIT_GIT_SSH_URL}" ]; then
        GIT_URL="$${GERRIT_GIT_SSH_URL}"
        echo "Using SSH URL for cloning (no authentication required)"
      else
        GIT_URL="$${GERRIT_GIT_HTTP_URL}"
        echo "Using HTTP URL for cloning"
      fi

      # Construct changeRef if we have change and patchset but changeRef is missing
      if [ -z "$${GERRIT_CHANGE_REF}" ] && [ -n "$${GERRIT_CHANGE}" ] && [ -n "$${GERRIT_PATCHSET}" ]; then
        CHANGE_NUM="$${GERRIT_CHANGE}"
        PATCHSET="$${GERRIT_PATCHSET}"
        # Calculate last two digits of change number (e.g., 12345 -> 45)
        # Use sed to extract last 2 digits, or pad with zero if single digit
        LAST_TWO="$$(echo "$$CHANGE_NUM" | sed 's/.*\(..\)$/\1/')"
        if [ "$$(echo -n "$$CHANGE_NUM" | wc -c)" -lt 2 ]; then
          LAST_TWO="$$(printf "%02d" "$$CHANGE_NUM")"
        fi
        GERRIT_CHANGE_REF="refs/changes/$$LAST_TWO/$$CHANGE_NUM/$$PATCHSET"
        echo "Constructed GERRIT_CHANGE_REF: $${GERRIT_CHANGE_REF}"
        export GERRIT_CHANGE_REF
      fi

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
        # For HTTP URLs, configure git to skip authentication prompts
        if echo "$GIT_URL" | grep -q "^http"; then
          # Configure git credential helper to store or cache credentials
          # Use empty helper to disable askpass, or configure .netrc if available
          GIT_CREDENTIAL_HELPER=""
          if [ -f "$HOME/.netrc" ]; then
            echo "Using .netrc for authentication"
          else
            echo "Warning: No .netrc found. HTTP cloning may require manual authentication."
            echo "Consider using SSH URL or configuring git credentials."
          fi
        fi

        git clone "$GIT_URL" "$REPO_DIR" || {
          echo "Error: Failed to clone repository"
          echo "If using HTTP URL, you may need to configure git credentials or use SSH URL"
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
    "CODER_SESSION_TOKEN=${var.coder_session_token}",
    # Gerrit rich parameters from coder-workspace plugin
    "GERRIT_GIT_HTTP_URL=${data.coder_parameter.gerrit_git_http_url.value}",
    "GERRIT_GIT_SSH_URL=${data.coder_parameter.gerrit_git_ssh_url.value}",
    "GERRIT_CHANGE_REF=${data.coder_parameter.gerrit_change_ref.value}",
    "GERRIT_CHANGE=${data.coder_parameter.gerrit_change.value}",
    "GERRIT_PATCHSET=${data.coder_parameter.gerrit_patchset.value}",
    "REPO=${data.coder_parameter.repo.value}"
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
