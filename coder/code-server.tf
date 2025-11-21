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

variable "gerrit_ssh_private_key" {
  description = "Optional private key material to write to ~/.ssh/id_gerrit (plain text)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gerrit_ssh_private_key_b64" {
  description = "Optional base64-encoded private key material to write to ~/.ssh/id_gerrit"
  type        = string
  default     = ""
  sensitive   = true
}

# Note: SSH key can be provided via:
# 1. gerrit_ssh_private_key_b64 Terraform variable (set per-workspace)
# 2. Coder secret 'gerrit_ssh_private_key_b64' (read by startup script via API)
#
# run.sh automatically:
# - Sets the variable in terraform.tfvars (for template validation)
# - Creates Coder secret 'gerrit_ssh_private_key_b64' (for runtime access)
#
# The startup script will attempt to read from the Coder secret if the
# variable is empty, ensuring persistent keys work across workspace restarts.

# Rich parameters from coder-workspace plugin
# These are accessed via data sources, not variables
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

data "coder_parameter" "gerrit_ssh_username" {
  name        = "GERRIT_SSH_USERNAME"
  description = "Preferred SSH username for Gerrit access"
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
    GERRIT_GIT_SSH_URL  = data.coder_parameter.gerrit_git_ssh_url.value
    GERRIT_CHANGE_REF   = data.coder_parameter.gerrit_change_ref.value
    GERRIT_CHANGE       = data.coder_parameter.gerrit_change.value
    GERRIT_PATCHSET     = data.coder_parameter.gerrit_patchset.value
    GERRIT_SSH_USERNAME = data.coder_parameter.gerrit_ssh_username.value
    REPO                = data.coder_parameter.repo.value
    GERRIT_SSH_PRIVATE_KEY     = var.gerrit_ssh_private_key
    GERRIT_SSH_PRIVATE_KEY_B64 = var.gerrit_ssh_private_key_b64
  }
  startup_script = <<-EOT
    #!/bin/sh
    set -e

    # Debug: Print environment variables for troubleshooting
    echo "=== Debug: Gerrit Environment Variables ==="
    echo "GERRIT_GIT_SSH_URL: $${GERRIT_GIT_SSH_URL:-<not set>}"
    echo "GERRIT_CHANGE_REF: $${GERRIT_CHANGE_REF:-<not set>}"
    echo "GERRIT_CHANGE: $${GERRIT_CHANGE:-<not set>}"
    echo "GERRIT_PATCHSET: $${GERRIT_PATCHSET:-<not set>}"
    echo "GERRIT_SSH_USERNAME: $${GERRIT_SSH_USERNAME:-<not set>}"
    echo "REPO: $${REPO:-<not set>}"
    if [ -n "$${GERRIT_SSH_PRIVATE_KEY_B64:-}" ]; then
      echo "GERRIT_SSH_PRIVATE_KEY_B64: <set>"
    else
      echo "GERRIT_SSH_PRIVATE_KEY_B64: <not set>"
    fi
    if [ -n "$${GERRIT_SSH_PRIVATE_KEY:-}" ]; then
      echo "GERRIT_SSH_PRIVATE_KEY: <set>"
    else
      echo "GERRIT_SSH_PRIVATE_KEY: <not set>"
    fi
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

    # Ensure ssh-keyscan (openssh-client) is available for host key setup
    if ! command -v ssh-keyscan >/dev/null 2>&1; then
      echo "Installing openssh-client for ssh-keyscan..."
      apt-get update -qq && apt-get install -y -qq openssh-client
    fi

    # Configure git to not use Coder's askpass for Gerrit URLs
    # This prevents authentication errors when cloning from Gerrit
    git config --global credential.helper ""
    git config --global ssh.variant ssh || true
    git config --global core.sshCommand "" || true
    # Disable Coder's askpass for Gerrit URLs
    if [ -n "$${GIT_ASKPASS}" ]; then
      echo "Unsetting GIT_ASKPASS=$${GIT_ASKPASS}"
      unset GIT_ASKPASS
    fi
    export GIT_ASKPASS=""

    # Ensure we use the system ssh binary instead of the Coder gitssh wrapper
    if [ -n "$${GIT_SSH}" ]; then
      echo "Unsetting existing GIT_SSH=$${GIT_SSH} to avoid overrides"
      unset GIT_SSH
    fi
    SSH_BIN="$(command -v ssh || true)"
    if [ -z "$${SSH_BIN}" ]; then
      echo "Error: ssh binary not found in PATH"
      exit 1
    fi
    echo "Using SSH binary: $${SSH_BIN}"

    # Precreate SSH directory and config placeholder
    mkdir -p /home/coder/.ssh
    if [ ! -f /home/coder/.ssh/config ]; then
      touch /home/coder/.ssh/config
      chmod 600 /home/coder/.ssh/config
      echo "# Managed by coder code-server.tf" > /home/coder/.ssh/config
    fi

    export GIT_SSH_COMMAND="$${SSH_BIN} -F /home/coder/.ssh/config -o StrictHostKeyChecking=yes"

    SKIP_GIT_CLONE=""

      # Clone Gerrit repository and cherry-pick patchset if SSH URL is provided
      # These environment variables are passed as rich parameters from the coder-workspace plugin
      if [ -n "$${SKIP_GIT_CLONE}" ]; then
        echo "Skipping Gerrit clone because the SSH key has not been authorized yet."
        echo "Once Gerrit accepts the key printed above, restart the workspace (or rerun the git commands manually)."
      elif [ -n "$${GERRIT_GIT_SSH_URL}" ]; then
      REPO_DIR="$${REPO:-gerrit-repo}"
      GIT_URL="$${GERRIT_GIT_SSH_URL}"

      # Parse Gerrit SSH URL into host/port/user (POSIX-friendly parsing)
      # Parse Gerrit SSH URL into host/port/user (prefer python3 for accuracy)
      PARSE_RESULT=""
      if command -v python3 >/dev/null 2>&1; then
        PARSE_RESULT="$(GERRIT_URL="$${GIT_URL}" python3 <<'PY'
import os, urllib.parse
url = os.environ.get("GERRIT_URL", "").strip()
if not url:
    url = ""
if url and not url.startswith("ssh://"):
    url = "ssh://" + url
parsed = urllib.parse.urlparse(url or "ssh://")
host = parsed.hostname or ""
port = str(parsed.port or "")
user = parsed.username or ""
print(f"{host}::{port}::{user}")
PY
        )"
      fi
      IFS="::" read -r PARSED_HOST PARSED_PORT PARSED_USER <<EOF
$${PARSE_RESULT:-::}
EOF

      if [ -n "$${PARSED_HOST}" ]; then
        GIT_HOST="$${PARSED_HOST}"
        GIT_PORT="$${PARSED_PORT}"
        GIT_USER_PART="$${PARSED_USER}"
      else
        URL_BODY="$${GIT_URL#ssh://}"
        if printf '%s' "$${URL_BODY}" | grep -q "@"; then
          GIT_USER_PART="$${URL_BODY%%@*}"
          HOST_PORT_PATH="$${URL_BODY#*@}"
        else
          GIT_USER_PART=""
          HOST_PORT_PATH="$${URL_BODY}"
        fi
        GIT_HOST="$${HOST_PORT_PATH%%[:/]*}"
        REST_AFTER_HOST="$${HOST_PORT_PATH#$${GIT_HOST}}"
        if printf '%s' "$${REST_AFTER_HOST}" | grep -q '^:'; then
          GIT_PORT="$${REST_AFTER_HOST#:}"
          GIT_PORT="$${GIT_PORT%%/*}"
        else
          GIT_PORT=""
        fi
      fi

      # Sanitize placeholder values (Coder may inject sentinel strings like 111FOO)
      sanitize_placeholder() {
        case "$1" in
          111[A-Z0-9_]*)
            printf ''
            ;;
          *)
            printf '%s' "$1"
            ;;
        esac
      }

      GIT_HOST="$(sanitize_placeholder "$${GIT_HOST:-}")"
      GIT_PORT="$(sanitize_placeholder "$${GIT_PORT:-}")"
      GIT_USER_PART="$(sanitize_placeholder "$${GIT_USER_PART:-}")"
      GIT_USER="$(sanitize_placeholder "$${GIT_USER:-}")"

      DEFAULT_GERRIT_SSH_PORT="$${GERRIT_SSH_PORT:-29418}"
      if ! printf '%s' "$${GIT_PORT}" | grep -Eq '^[0-9]+$'; then
        GIT_PORT=""
      fi
      if [ -z "$${GIT_PORT}" ]; then
        GIT_PORT="$${DEFAULT_GERRIT_SSH_PORT}"
      fi
      if [ -n "$${GIT_USER_PART}" ]; then
        GIT_USER="$${GIT_USER_PART}"
      elif [ -n "$${GERRIT_SSH_USERNAME}" ]; then
        GIT_USER="$${GERRIT_SSH_USERNAME}"
      else
        GIT_USER="admin"
      fi

      # Allow explicit overrides from environment (if provided by template vars)
      if [ -n "$${GERRIT_SSH_HOST}" ]; then
        GIT_HOST="$${GERRIT_SSH_HOST}"
      fi
      if [ -n "$${GERRIT_SSH_PORT}" ]; then
        GIT_PORT="$${GERRIT_SSH_PORT}"
      fi
      if [ -n "$${GERRIT_SSH_USERNAME}" ]; then
        GIT_USER="$${GERRIT_SSH_USERNAME}"
      fi

      echo "Parsed Gerrit SSH parameters: host=$${GIT_HOST} port=$${GIT_PORT} user=$${GIT_USER}"

      KNOWN_HOSTS=/home/coder/.ssh/known_hosts
      touch "$${KNOWN_HOSTS}"
      chmod 600 "$${KNOWN_HOSTS}"
      if [ -n "$${GIT_HOST}" ]; then
        echo "Ensuring host key for $${GIT_HOST}:$${GIT_PORT}"
        if ssh-keyscan -p "$${GIT_PORT}" "$${GIT_HOST}" >> "$${KNOWN_HOSTS}" 2>/dev/null; then
          sort -u "$${KNOWN_HOSTS}" -o "$${KNOWN_HOSTS}" || true
        else
          echo "Warning: ssh-keyscan failed for $${GIT_HOST}:$${GIT_PORT}"
        fi
      fi

      # Determine identity file (override via GERRIT_SSH_IDENTITY if provided)
      SSH_IDENTITY="$(sanitize_placeholder "$${GERRIT_SSH_IDENTITY:-}")"

      # If GERRIT_SSH_PRIVATE_KEY_B64 is empty, try to read from Coder secret via API
      if [ -z "$${GERRIT_SSH_PRIVATE_KEY_B64:-}" ] && [ -n "$${CODER_AGENT_URL:-}" ] && command -v curl >/dev/null 2>&1; then
        CODER_API_URL="$${CODER_AGENT_URL%/}"
        # Try to get secret from Coder API (requires CODER_SESSION_TOKEN or agent token)
        CODER_TOKEN="$${CODER_SESSION_TOKEN:-$${CODER_AGENT_TOKEN:-}}"
        if [ -n "$${CODER_TOKEN:-}" ]; then
          echo "Attempting to read SSH key from Coder secret 'gerrit_ssh_private_key_b64'..."
          # Use a temporary file to avoid quote issues with command substitution
          TMP_RESPONSE="/tmp/coder_secret_response.json"
          if curl -s -f -H "Coder-Session-Token: $${CODER_TOKEN}" \
            "$${CODER_API_URL}/api/v2/secrets/gerrit_ssh_private_key_b64" > "$${TMP_RESPONSE}" 2>/dev/null; then
            # Try jq first, fallback to grep/sed
            if command -v jq >/dev/null 2>&1; then
              SECRET_VALUE="$$(jq -r '.value // empty' "$${TMP_RESPONSE}" 2>/dev/null || true)"
            else
              SECRET_VALUE="$$(grep -o '\"value\":\"[^\"]*' "$${TMP_RESPONSE}" 2>/dev/null | sed 's/\"value\":\"//' | sed 's/\"\$//' || true)"
            fi
            rm -f "$${TMP_RESPONSE}"
            if [ -n "$${SECRET_VALUE:-}" ] && [ "$${SECRET_VALUE}" != "null" ]; then
              export GERRIT_SSH_PRIVATE_KEY_B64="$${SECRET_VALUE}"
              echo "Successfully retrieved SSH key from Coder secret"
            else
              echo "Coder secret 'gerrit_ssh_private_key_b64' not found or not accessible"
            fi
          else
            echo "Failed to fetch Coder secret (API request failed)"
          fi
        fi
      fi

      # Check for injected private key material (from Terraform variables or Coder secret)
      if [ -z "$${SSH_IDENTITY}" ] && [ -n "$${GERRIT_SSH_PRIVATE_KEY_B64}" ]; then
        echo "Found GERRIT_SSH_PRIVATE_KEY_B64, decoding into ~/.ssh/id_gerrit"
        DEST="/home/coder/.ssh/id_gerrit"
        umask 077
        if printf '%s' "$${GERRIT_SSH_PRIVATE_KEY_B64}" | base64 -d > "$${DEST}" 2>/dev/null; then
          chmod 600 "$${DEST}"
          if [ -f "$${DEST}" ] && [ -s "$${DEST}" ]; then
            SSH_IDENTITY="$${DEST}"
            echo "Successfully decoded and wrote SSH key to $${SSH_IDENTITY}"
          else
            echo "Warning: Decoded key file is empty or missing, will try other sources"
            rm -f "$${DEST}"
          fi
        else
          echo "Warning: Failed to decode GERRIT_SSH_PRIVATE_KEY_B64, will try other sources"
        fi
      fi

      if [ -z "$${SSH_IDENTITY}" ] && [ -n "$${GERRIT_SSH_PRIVATE_KEY}" ]; then
        echo "Found GERRIT_SSH_PRIVATE_KEY, writing into ~/.ssh/id_gerrit"
        DEST="/home/coder/.ssh/id_gerrit"
        umask 077
        printf '%s\n' "$${GERRIT_SSH_PRIVATE_KEY}" > "$${DEST}"
        chmod 600 "$${DEST}"
        if [ -f "$${DEST}" ] && [ -s "$${DEST}" ]; then
          SSH_IDENTITY="$${DEST}"
          echo "Successfully wrote SSH key to $${SSH_IDENTITY}"
        else
          echo "Warning: Written key file is empty or missing, will try other sources"
          rm -f "$${DEST}"
        fi
      fi

      if [ -z "$${SSH_IDENTITY}" ]; then
        for candidate in \
          /home/coder/.ssh/id_ed25519 \
          /home/coder/.ssh/id_rsa \
          /home/coder/.ssh/id_dsa \
          /home/coder/.config/coderv2/ssh/id_ed25519 \
          /home/coder/.config/coderv2/ssh/id_rsa; do
          if [ -z "$${SSH_IDENTITY}" ] && [ -f "$${candidate}" ]; then
            SSH_IDENTITY="$${candidate}"
          fi
        done
      fi

      AUTO_SSH_KEY="/home/coder/.ssh/id_ed25519_coder"
      if [ -z "$${SSH_IDENTITY}" ]; then
        if [ -f "$${AUTO_SSH_KEY}" ]; then
          SSH_IDENTITY="$${AUTO_SSH_KEY}"
          echo "Reusing previously generated SSH key: $${SSH_IDENTITY}"
        else
          echo "No SSH identity found and no key provided via GERRIT_SSH_PRIVATE_KEY(_B64)."
          echo "Generating a new ed25519 key at $${AUTO_SSH_KEY}..."
          echo "Note: This key will be lost on workspace restart. For persistent keys, use run.sh"
          echo "      which automatically manages SSH keys, or set gerrit_ssh_private_key(_b64)"
          echo "      Terraform variables in your template configuration."
          if ssh-keygen -t ed25519 -N "" -f "$${AUTO_SSH_KEY}" >/tmp/ssh-keygen.log 2>&1; then
            SSH_IDENTITY="$${AUTO_SSH_KEY}"
            chmod 600 "$${SSH_IDENTITY}"
            echo "Generated SSH key. Public key (add to Gerrit > Settings > SSH Public Keys):"
            cat "$${SSH_IDENTITY}.pub"
            echo "After adding the key to Gerrit, restart this workspace (or rerun the git commands manually) once Gerrit reports the key as active."
            SKIP_GIT_CLONE="missing-key"
          else
            echo "Error: Failed to generate SSH key."
            cat /tmp/ssh-keygen.log || true
            exit 1
          fi
        fi
      fi

      if [ ! -f "$${SSH_IDENTITY}" ]; then
        echo "Error: SSH identity file $${SSH_IDENTITY} not found."
        exit 1
      fi
      echo "Using SSH identity file: $${SSH_IDENTITY}"

      SSH_CONFIG=/home/coder/.ssh/config
      ADD_IDENTITY_LINE=false
      if [ -n "$${SSH_IDENTITY}" ] && [ -f "$${SSH_IDENTITY}" ]; then
        ADD_IDENTITY_LINE=true
      elif [ -n "$${SSH_IDENTITY}" ]; then
        echo "Warning: Identity file $${SSH_IDENTITY} not found; skipping IdentityFile entry."
      fi
      {
        echo "# Managed by coder code-server.tf"
        echo "Host *"
        if [ -n "$${GIT_HOST}" ]; then
          echo "  HostName $${GIT_HOST}"
        fi
        if [ -n "$${GIT_PORT}" ]; then
          echo "  Port $${GIT_PORT}"
        fi
        if [ -n "$${GIT_USER}" ]; then
          echo "  User $${GIT_USER}"
        fi
        if [ "$${ADD_IDENTITY_LINE}" = "true" ]; then
          echo "  IdentityFile $${SSH_IDENTITY}"
        fi
        echo "  IdentitiesOnly yes"
        echo "  StrictHostKeyChecking yes"
        echo "  UserKnownHostsFile $${KNOWN_HOSTS}"
      } > "$${SSH_CONFIG}"
      chmod 600 "$${SSH_CONFIG}"
      echo "Wrote $${SSH_CONFIG}:"
      cat "$${SSH_CONFIG}"

      export GIT_SSH_COMMAND="$${SSH_BIN} -F $${SSH_CONFIG} -o StrictHostKeyChecking=yes"

      # Construct changeRef if we have change and patchset but changeRef is missing
      if [ -z "$${GERRIT_CHANGE_REF}" ] && [ -n "$${GERRIT_CHANGE}" ] && [ -n "$${GERRIT_PATCHSET}" ]; then
        CHANGE_NUM="$${GERRIT_CHANGE}"
        PATCHSET="$${GERRIT_PATCHSET}"
        # Calculate last two digits of change number (e.g., 12345 -> 45)
        # Use sed to extract last 2 digits, or pad with zero if single digit
        LAST_TWO="$$(echo "$${CHANGE_NUM}" | sed 's/.*\(..\)$/\1/')"
        if [ "$$(echo -n "$${CHANGE_NUM}" | wc -c)" -lt 2 ]; then
          LAST_TWO="$$(printf "%02d" "$${CHANGE_NUM}")"
        fi
        GERRIT_CHANGE_REF="refs/changes/$${LAST_TWO}/$${CHANGE_NUM}/$${PATCHSET}"
        echo "Constructed GERRIT_CHANGE_REF: $${GERRIT_CHANGE_REF}"
        export GERRIT_CHANGE_REF
      fi

      if [ -n "$${SKIP_GIT_CLONE}" ]; then
        echo "Skipping Gerrit clone because the SSH key has not been authorized yet."
        echo "Once Gerrit accepts the generated key, restart the workspace (or rerun the git commands manually)."
      elif [ -n "$${GERRIT_GIT_SSH_URL}" ]; then
        echo "Cloning Gerrit repository from $GIT_URL (SSH)..."

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
          # Clone the repository via SSH
          echo "Cloning repository from $GIT_URL (SSH)..."
          git clone "$GIT_URL" "$REPO_DIR" || {
            echo "Error: Failed to clone repository"
            echo "Ensure SSH keys are configured for Gerrit access."
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
    "GERRIT_GIT_SSH_URL=${data.coder_parameter.gerrit_git_ssh_url.value}",
    "GERRIT_CHANGE_REF=${data.coder_parameter.gerrit_change_ref.value}",
    "GERRIT_CHANGE=${data.coder_parameter.gerrit_change.value}",
    "GERRIT_PATCHSET=${data.coder_parameter.gerrit_patchset.value}",
    "GERRIT_SSH_USERNAME=${data.coder_parameter.gerrit_ssh_username.value}",
    "REPO=${data.coder_parameter.repo.value}",
    "GERRIT_SSH_PRIVATE_KEY=${var.gerrit_ssh_private_key}",
    "GERRIT_SSH_PRIVATE_KEY_B64=${var.gerrit_ssh_private_key_b64}"
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
