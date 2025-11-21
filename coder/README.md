# Coder Test

This directory contains scripts and configuration files to set up a complete test environment for the Coder Workspace Gerrit plugin with Terraform-based workspace management.

## 🚀 Quick Start

### Option 1: Complete Automated Setup
```bash
# Run complete setup (handles everything automatically)
# It will create .env from env.example and prompt you to edit it
# It also automatically generates/manages SSH keys for Gerrit access
./run.sh
```

**SSH Key Management:**
- On first run, `run.sh` automatically generates an SSH key at `~/.ssh/gerrit_workspace_ed25519` (or the path specified by `GERRIT_SSH_KEY_PATH`)
- The public key is displayed in the output - **copy it and add it to Gerrit** (Settings → SSH Public Keys)
- On subsequent runs, the same key is reused, ensuring consistent authentication
- The private key is automatically base64-encoded and passed to the Terraform template
- Alternatively, you can set `GERRIT_SSH_PRIVATE_KEY` or `GERRIT_SSH_PRIVATE_KEY_B64` in your `.env` file to use an existing key

### Option 2: Terraform-Based Setup
```bash
# Load environment variables
source ./load-env.sh

# Run Terraform-based setup
./setup-terraform.sh
```

### Option 3: Manual Step-by-Step Setup
```bash
# Copy environment template and customize
cp env.example .env
# Edit .env with your values

# Load environment variables
source ./load-env.sh

# Apply environment variables to configuration files
./apply-env-to-yaml.sh

# Start Coder server
./coder.sh

# Deploy template
./template.sh
```

## 📋 Environment Variables

Configure the test environment using these environment variables (set in `.env` file):

| Variable | Description | Default |
|----------|-------------|---------|
| `GERRIT_URL` | Gerrit server URL | `http://127.0.0.1:8080` |
| `CODER_PORT` | Coder server port | `3000` |
| `CODER_ACCESS_URL` | External Coder URL | `http://127.0.0.1:3000` |
| `CODER_URL` | Internal Coder URL for CLI | `http://127.0.0.1:3000` |
| `CODER_TEMPLATE_NAME` | Template name | `vscode-web` |
| `CODER_SESSION_TOKEN` | Coder API token for authentication | *(required)* |
| `GERRIT_SSH_USERNAME` | Preferred SSH username (overrides username parsed from `GERRIT_GIT_SSH_URL`) | *(optional)* |
| `GERRIT_SSH_KEY_PATH` | Path to SSH private key file for Gerrit access (auto-generated if not set) | `~/.ssh/gerrit_workspace_ed25519` |
| `GERRIT_SSH_PRIVATE_KEY` | Plain-text SSH private key material (alternative to `GERRIT_SSH_KEY_PATH`) | *(optional)* |
| `GERRIT_SSH_PRIVATE_KEY_B64` | Base64-encoded SSH private key material (alternative to `GERRIT_SSH_KEY_PATH`) | *(optional)* |

### Example `.env` file:
```bash
# Gerrit Configuration
GERRIT_URL="http://your-gerrit-server:8080"

# Coder Configuration
CODER_PORT="3000"
CODER_ACCESS_URL="http://your-coder-server:3000"
CODER_URL="http://127.0.0.1:3000"

# Template Configuration
CODER_TEMPLATE_NAME="vscode-web"

# Authentication
CODER_SESSION_TOKEN="your-coder-session-token"

# SSH Key Configuration (optional - auto-generated if not set)
# GERRIT_SSH_KEY_PATH="~/.ssh/gerrit_workspace_ed25519"
# Or provide the key directly:
# GERRIT_SSH_PRIVATE_KEY_B64="base64-encoded-private-key"
```

## 🔧 Gerrit Plugin Configuration

Configure your Gerrit plugin with the values from your environment:

```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = http://your-coder-server:3000  # Use CODER_ACCESS_URL from .env
  apiKey = ${secret:coder/session_token}  # Use CODER_SESSION_TOKEN from .env
  templateId = YOUR_TEMPLATE_ID
  organization = YOUR_ORGANIZATION_ID
  openAfterCreate = true
  enableDryRunPreview = false
  ttlMs = 0
  # Enable/disable repository cloning (default: true)
  # When enabled, git-related rich parameters (GERRIT_GIT_SSH_URL, GERRIT_CHANGE_REF)
  # are passed to the workspace template, enabling automatic repository cloning.
  enableCloneRepository = true
```

## 📁 Files Overview

### 🚀 Main Setup Scripts

| Script | Description |
|--------|-------------|
| **`run.sh`** | Complete automated setup (recommended) - includes automatic SSH key generation and management |
| **`setup-terraform.sh`** | Terraform-based setup |
| **`load-env.sh`** | Loads environment variables from .env file |

### 🔧 Configuration Scripts

| Script | Description |
|--------|-------------|
| **`apply-env-to-yaml.sh`** | Applies environment variables to YAML files |
| **`env-to-terraform.sh`** | Converts .env to terraform.tfvars (includes SSH key handling) |
| **`coder.sh`** | Starts Coder server with Docker |
| **`template.sh`** | Deploys the VS Code template to Coder |

### 🧹 Utility Scripts

| Script | Description |
|--------|-------------|
| **`cleanup-containers.sh`** | Removes conflicting Docker containers (name collisions) |

### 📋 Configuration Files

| File | Description |
|------|-------------|
| **`.env`** | Environment variables (copy from env.example) |
| **`env.example`** | Environment variables template |
| **`coder.yaml`** | Coder server configuration |
| **`coder-explicit.yaml`** | Explicit configuration (no env vars) |
| **`code-server.tf`** | Terraform template for VS Code workspace |
| **`terraform.tfvars`** | Terraform variables (generated from .env) |

## 🏗️ Detailed Setup

### 1. Environment Configuration

The setup uses environment variables for flexible configuration:

```bash
# Copy template and customize
cp env.example .env
# Edit .env with your specific values

# Load environment variables
source ./load-env.sh
```

**Key Features:**
- ✅ No hardcoded URLs - uses `GERRIT_URL` from environment
- ✅ Flexible port configuration via `CODER_PORT`
- ✅ Automatic environment variable substitution
- ✅ Support for both `.env` file and export statements

### 2. Coder Server Setup

The `coder.sh` script starts a Coder server with:
- Docker-based deployment
- Gerrit integration
- External access on configurable port
- Proper volume mounts for persistence

**Environment Variables:**
- `CODER_PORT` - Coder server port (default: 3000)
- `CODER_ACCESS_URL` - External URL for Coder
- `CODER_URL` - Internal URL for CLI
- `CODER_TEMPLATE_NAME` - Template name (default: vscode-web)

### 3. Terraform Integration

The `code-server.tf` file includes:
- Docker container configuration with proper environment variables
- Flexible configuration via Terraform variables
- Host networking for the workspace container so `127.0.0.1:3000` reaches the host Coder server
- Direct agent startup with provided URL/token (no probing required in normal cases)
- Automatic git repository cloning and cherry-pick support (see [Git Repository Cloning](#git-repository-cloning) below)

**Terraform Variables:**
- `coder_access_url` - Uses `CODER_ACCESS_URL` from environment
- `gerrit_url` - Uses `GERRIT_URL` from environment
- `gerrit_ssh_private_key` *(optional, sensitive)* - Plain-text private key material written to `~/.ssh/id_gerrit` inside the workspace (ideal when wiring a Coder secret into the template)
- `gerrit_ssh_private_key_b64` *(optional, sensitive)* - Base64-encoded private key material, decoded into `~/.ssh/id_gerrit`. Takes precedence over the plain-text variant when both are set.

**Rich Parameters (via `data "coder_parameter"`):**
- `GERRIT_GIT_SSH_URL`, `GERRIT_CHANGE_REF`, `GERRIT_CHANGE`, `GERRIT_PATCHSET`, `REPO` - Rich parameters from coder-workspace plugin (automatically passed when workspace is created from Gerrit change)
- `GERRIT_SSH_USERNAME` - Optional parameter to explicitly set the SSH username used when cloning (helpful when Gerrit accounts differ from the username embedded in the SSH URL)
- These are accessed via `data "coder_parameter"` data sources, not Terraform variables
- Coder automatically populates these data sources with values from the rich parameters sent by the plugin
- **Note:** Git-related parameters (`GERRIT_GIT_SSH_URL` and `GERRIT_CHANGE_REF`) are only included when `enableCloneRepository = true` (default) in the Gerrit plugin configuration. If disabled, these parameters will be empty and the template will skip cloning.
- **Note:** The plugin only supports SSH cloning. Ensure SSH keys are configured in your workspace for Gerrit access.

**Important: Terraform Interpolation Escaping**

When writing shell scripts inside Terraform heredoc strings (like the `startup_script`), shell variable references must be escaped to prevent Terraform from interpreting them as Terraform interpolation expressions:

- Use `$${VAR}` instead of `${VAR}` for shell variables
- Use `$${VAR:-default}` instead of `${VAR:-default}` for shell variable substitution with defaults
- This tells Terraform to output a literal `${}` in the generated script, which the shell will then interpret

**Example:**
```hcl
# ❌ Wrong - Terraform will try to interpolate this
startup_script = <<-EOT
  REPO_DIR="${REPO:-gerrit-repo}"
EOT

# ✅ Correct - Escaped for shell variable substitution
startup_script = <<-EOT
  REPO_DIR="$${REPO:-gerrit-repo}"
EOT
```

If you see errors like "Invalid character" or "Extra characters after interpolation expression" when running `coder templates push`, check that all shell variables in heredoc strings are properly escaped with `$${}`.

### 4. Git Repository Cloning

The `code-server.tf` template automatically clones Gerrit repositories and cherry-picks patchsets when workspaces are created from Gerrit changes. This feature uses rich parameters passed from the coder-workspace plugin.

**Configuration:**
- Repository cloning is controlled by the `enableCloneRepository` option in the Gerrit plugin configuration (default: `true`)
- When `enableCloneRepository = false`, git-related parameters (`GERRIT_GIT_SSH_URL` and `GERRIT_CHANGE_REF`) are not passed to the workspace, and the template will skip cloning
- The template gracefully handles missing parameters and will skip cloning if they are not provided

**How It Works:**
1. When a workspace is created from a Gerrit change, the coder-workspace plugin passes rich parameters (if `enableCloneRepository = true`):
   - `GERRIT_GIT_SSH_URL`: SSH git repository URL
   - `GERRIT_CHANGE_REF`: Patchset ref (e.g., `refs/changes/45/12345/2`)
   - `REPO`: Repository name (used as directory name)
   - `GERRIT_CHANGE` and `GERRIT_PATCHSET`: Change and patchset numbers

2. The Terraform template (`code-server.tf`) accesses these via `data "coder_parameter"` data sources and passes them to the agent and Docker container:
   - All Gerrit-related rich parameters are declared as `data "coder_parameter"` blocks
   - These are passed to the `coder_agent` via the `env` attribute
   - They are also included in the Docker container's `env` array
   - This ensures the environment variables are available to the startup script

3. The startup script in `code-server.tf` automatically:
   - Configures git to disable Coder's askpass (prevents authentication conflicts)
   - Installs git if not already present
   - Auto-constructs `GERRIT_CHANGE_REF` from `GERRIT_CHANGE` and `GERRIT_PATCHSET` if missing
   - Clones the repository using SSH URL
   - Fetches and cherry-picks the patchset
   - Handles existing repositories gracefully
   - Provides helpful error messages for conflicts

**Features:**
- ✅ Automatic git installation
- ✅ SSH-only cloning (requires SSH keys configured in workspace)
- ✅ Auto-construction of `GERRIT_CHANGE_REF` from change and patchset numbers if missing
- ✅ Smart repository handling (clones new, updates existing)
- ✅ Automatic cherry-pick of patchsets
- ✅ Conflict detection and helpful error messages

**Repository Location:**
- Default directory: `gerrit-repo` (or uses `REPO` rich parameter value)
- Located in workspace home directory: `/home/coder/gerrit-repo`

**SSH Authentication:**

The plugin uses SSH URLs for cloning. SSH keys are automatically managed by the setup scripts.

**Automated SSH Key Management:**

The `run.sh` script provides seamless SSH key management:

1. **Automatic Key Generation**: On first run, if no SSH key is provided, `run.sh` generates a new ed25519 key at `~/.ssh/gerrit_workspace_ed25519` (or the path specified by `GERRIT_SSH_KEY_PATH`)

2. **Key Reuse**: On subsequent runs, the same key is automatically reused, ensuring consistent authentication across workspace restarts

3. **Public Key Display**: The public key is displayed in the output - simply copy it and add it to Gerrit (Settings → SSH Public Keys)

4. **Automatic Integration**: The private key is automatically base64-encoded and passed to the Terraform template via `env-to-terraform.sh`, ensuring every workspace uses the same credentials

5. **Manual Override**: You can override this by setting `GERRIT_SSH_PRIVATE_KEY` or `GERRIT_SSH_PRIVATE_KEY_B64` in your `.env` file to use an existing key

**Workflow:**
```bash
# First run - generates key and shows public key
./run.sh
# Output: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
# → Copy this key and add it to Gerrit

# After adding key to Gerrit, subsequent runs reuse the same key
./run.sh  # Uses existing key automatically
```

The workspace startup script now automatically:
- Installs `openssh-client` (for `ssh-keyscan`) if it is missing
- Parses `GERRIT_GIT_SSH_URL` (preferring a `python3` URL parser with a POSIX fallback) to extract the host/user/port
- Adds or refreshes the host's public key in `/home/coder/.ssh/known_hosts` using `ssh-keyscan`
- Deduplicates and locks down `known_hosts`
- Rewrites `/home/coder/.ssh/config` with a managed `Host *` entry that pins the Gerrit hostname, port, user, and SSH identity. Host/port/user come from the SSH URL, but you can override them via `GERRIT_SSH_HOST`, `GERRIT_SSH_PORT`, and `GERRIT_SSH_USERNAME` (fallback user `admin`). Identity defaults to `~/.ssh/id_ed25519`/`id_rsa` if available, can be overridden with `GERRIT_SSH_IDENTITY`, or injected via the new `gerrit_ssh_private_key(_b64)` Terraform variables (surfaced to the startup script as `GERRIT_SSH_PRIVATE_KEY` / `_B64`).
- Writes inline private key material (when provided) to `~/.ssh/id_gerrit` with strict permissions before configuring SSH.
- When no key exists at all, auto-generates an ed25519 key at `~/.ssh/id_ed25519_coder`, prints the public key in the startup logs, and keeps the workspace running while skipping the git clone. After you paste the key into Gerrit, simply restart the workspace (or rerun the git commands manually) and the script will reuse the same key file, avoiding mismatched fingerprints.
- **Best practice:** Use the automated SSH key management in `run.sh` (recommended) or supply a stable key via the `gerrit_ssh_private_key` (plain text) or `gerrit_ssh_private_key_b64` (base64) Terraform variables. The automated approach ensures consistent keys across all workspace restarts without manual intervention.
- Forces git to use the system `ssh` binary via `GIT_SSH_COMMAND` (after unsetting any inherited `GIT_SSH`) instead of the `coder gitssh` helper so that standalone SSH keys work consistently in the workspace (the binary path is detected by running `command -v ssh` inside the container and logged).
- Normalizes `git`'s SSH settings (`git config --global ssh.variant ssh` and clears `core.sshCommand`) to avoid the `ssh variant 'simple' does not support setting port` error.

This allows Gerrit clones to proceed without manual host-key approval while still keeping the known-hosts file scoped to the Gerrit endpoint supplied by the plugin.

**Note:** The workspace template only supports SSH cloning. Make sure SSH keys are set up in the workspace (e.g., `~/.ssh/id_rsa` or similar). If you prefer to pre-provision host keys (instead of relying on automatic discovery), you can mount or template your own `known_hosts`; the automatic step simply appends entries when they are missing.

### 5. Template Deployment

The `template.sh` script deploys a VS Code workspace template:

**Features:**
- ✅ Copies Terraform template to container
- ✅ Authenticates with Coder CLI using `CODER_SESSION_TOKEN`
- ✅ Pushes template with proper configuration
- ✅ Handles token authentication gracefully
- ✅ Skips deployment if no token provided (with helpful message)

## 🔧 Troubleshooting

### Git Cloning Issues

If the repository cloning or cherry-pick fails:

```bash
# Check if rich parameters are being passed
# In the workspace, check environment variables:
docker exec -it coder-workspace-<name>-0 env | grep GERRIT

# Verify git is installed in the workspace
docker exec -it coder-workspace-<name>-0 git --version

# Check repository status
docker exec -it coder-workspace-<name>-0 bash -c "cd gerrit-repo && git status"

# View startup script logs
docker exec -it coder-workspace-<name>-0 cat /tmp/code-server.log
```

**Common Issues:**
- **Authentication failures**:
  - If using `run.sh`, ensure you've added the displayed public key to Gerrit (Settings → SSH Public Keys)
  - The automated key management ensures the same key is used across restarts - verify the key in Gerrit matches the one generated by `run.sh`
  - If using manual key setup, ensure SSH keys are configured in the workspace for Gerrit access
  - Check that SSH keys are properly set up (e.g., `~/.ssh/id_rsa` or similar)
  - Verify the key is added to the correct Gerrit user account (matching `GERRIT_SSH_USERNAME` or the username in the SSH URL)
- **Cherry-pick conflicts**: Resolve manually in the repository directory
- **Missing rich parameters**:
  - Ensure the coder-workspace plugin is properly configured in Gerrit
  - Verify that rich parameters are declared as `data "coder_parameter"` blocks in `code-server.tf`
  - Check that environment variables are passed to both the `coder_agent` and Docker container
  - If you see "No Gerrit git repository URL provided", verify the rich parameters are being passed from the plugin
  - Check the debug output at the start of the startup script to see which parameters are set

### Environment Variable Issues

If environment variables aren't being applied:
```bash
# Check if .env file exists and is loaded
source ./load-env.sh

# Verify environment variables
echo "GERRIT_URL: $GERRIT_URL"
echo "CODER_PORT: $CODER_PORT"
echo "CODER_ACCESS_URL: $CODER_ACCESS_URL"

# Reapply environment variables to configuration files
./apply-env-to-yaml.sh
./env-to-terraform.sh
```

### Container Issues

```bash
# Check Coder container status
docker ps | grep coder-server

# View Coder logs
docker logs coder-server

# Restart Coder
docker restart coder-server
```

### Startup Issues

If Coder fails to start or respond:

```bash
# Check if Coder is responding (HTTP 401 is normal for unauthenticated requests)
curl -v http://127.0.0.1:3000/api/v2/templates

# Check container logs for errors
docker logs coder-server --tail 50

# Restart Coder if needed
docker restart coder-server
```

**Note:** HTTP 401 (Unauthorized) responses are expected and indicate Coder is running correctly but requires authentication.

### Template Issues

```bash
# Check template deployment
docker exec coder-server /opt/coder templates list

# Redeploy template
./template.sh
```

### Terraform Template Parsing Errors

If you encounter errors when running `coder templates push`:

**Error: "Invalid character" or "Extra characters after interpolation expression"**

This typically occurs when shell variables in heredoc strings are not properly escaped. Terraform interprets `${}` as interpolation syntax, so shell variables must be escaped:

```bash
# Check for unescaped shell variables in code-server.tf
grep -n '\${[^$]' code-server.tf

# All shell variables should use $${} instead of ${}
# Example: $${GERRIT_CHANGE_REF} instead of ${GERRIT_CHANGE_REF}
```

**Common fixes:**
- Replace `${VAR}` with `$${VAR}` in heredoc strings
- Replace `${VAR:-default}` with `$${VAR:-default}` for shell variable substitution
- Ensure nested variables are also escaped: `$${VAR1:-$${VAR2}}`

**Validate Terraform syntax:**
```bash
# Check Terraform syntax
terraform fmt -check code-server.tf

# Format Terraform files
terraform fmt code-server.tf
```

## 🌐 Browser Development Setup

### Disabling CORS for Development

When developing with the coder-workspace and test directories, you may encounter CORS (Cross-Origin Resource Sharing) issues. To disable CORS for development purposes, launch Chrome or Edge with the `--disable-web-security` flag:

#### Chrome
```bash
# Windows
chrome.exe --user-data-dir="C:/temp/chrome_dev" --disable-web-security --disable-features=VizDisplayCompositor

# macOS
open -n -a /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --args --user-data-dir="/tmp/chrome_dev" --disable-web-security

# Linux
google-chrome --user-data-dir="/tmp/chrome_dev" --disable-web-security
```

#### Microsoft Edge
```bash
# Windows
msedge.exe --user-data-dir="C:/temp/edge_dev" --disable-web-security --disable-features=VizDisplayCompositor

# macOS
open -n -a /Applications/Microsoft\ Edge.app/Contents/MacOS/Microsoft\ Edge --args --user-data-dir="/tmp/edge_dev" --disable-web-security

# Linux
microsoft-edge --user-data-dir="/tmp/edge_dev" --disable-web-security
```

**⚠️ Important Security Note:**
- Only use these flags for development purposes
- Never use `--disable-web-security` for regular browsing
- The `--user-data-dir` flag creates a separate profile to avoid affecting your main browser data
- Close all browser windows before launching with these flags

## Configuration Examples

### Gerrit Configuration

```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = http://127.0.0.1:3000
  apiKey = ${secret:coder/session_token}
  templateId = 2d0e2208-8b2d-4ea5-9ba1-44a68cc5d27f
  organization = 7daa7856-045c-4589-b4af-dee232d16bb3
  openAfterCreate = true
  enableDryRunPreview = false
  ttlMs = 0
```

### Coder Configuration

```yaml
server:
  bind_address: "0.0.0.0:3000"
```

## 🚀 Development Workflow

### 1. Initial Setup
```bash
# Copy environment template and customize
cp env.example .env
# Edit .env with your values
nano .env

# Run complete setup (automatically manages SSH keys)
./run.sh

# On first run, copy the displayed SSH public key and add it to Gerrit:
# 1. Go to Gerrit → Settings → SSH Public Keys
# 2. Click "Add Key"
# 3. Paste the public key shown in the output
# 4. Save

# Subsequent runs will automatically reuse the same key
```

### 2. Get Configuration Values
```bash
# Load environment variables
source ./load-env.sh

# Get organization ID
curl -H "Coder-Session-Token: $CODER_SESSION_TOKEN" \
     $CODER_URL/api/v2/organizations

# Get template ID
curl -H "Coder-Session-Token: $CODER_SESSION_TOKEN" \
     $CODER_URL/api/v2/templates
```

### 3. Configure Gerrit Plugin
Use the values from step 2 in your Gerrit configuration:
```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = $CODER_ACCESS_URL  # From .env file
  apiKey = ${secret:coder/session_token}  # Use CODER_SESSION_TOKEN
  templateId = YOUR_TEMPLATE_ID  # From API call
  organization = YOUR_ORGANIZATION_ID  # From API call
  # Enable repository cloning (default: true)
  enableCloneRepository = true
```

### 4. Test Integration
- Open a change in Gerrit
- Click "Open Coder Workspace" in the overflow menu
- Check browser console for any errors
- Verify the repository is cloned and cherry-picked:
  - Open the workspace in VS Code
  - Check for `gerrit-repo` directory in the workspace
  - Verify the patchset is cherry-picked: `cd gerrit-repo && git log --oneline -5`

## 🧹 Cleanup

```bash
# Stop Coder container
docker stop coder-server

# Remove Coder data (optional)
rm -rf ~/.config/coderv2-docker

# Clean up Terraform state (optional)
terraform destroy -auto-approve
```
