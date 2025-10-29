# Coder Test

This directory contains scripts and configuration files to set up a complete test environment for the Coder Workspace Gerrit plugin with Terraform-based workspace management.

## 🚀 Quick Start

### Option 1: Complete Automated Setup
```bash
# Run complete setup (handles everything automatically)
# It will create .env from env.example and prompt you to edit it
./run.sh
```

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
  user = YOUR_USERNAME
  autostart = true
  automaticUpdates = always
  openAfterCreate = true
  enableDryRunPreview = false
  ttlMs = 0
```

## 📁 Files Overview

### 🚀 Main Setup Scripts

| Script | Description |
|--------|-------------|
| **`run.sh`** | Complete automated setup (recommended) |
| **`setup-terraform.sh`** | Terraform-based setup |
| **`load-env.sh`** | Loads environment variables from .env file |

### 🔧 Configuration Scripts

| Script | Description |
|--------|-------------|
| **`apply-env-to-yaml.sh`** | Applies environment variables to YAML files |
| **`env-to-terraform.sh`** | Converts .env to terraform.tfvars |
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
- Fixed Docker command to ensure workspace container starts reliably

**Terraform Variables:**
- `coder_access_url` - Uses `CODER_ACCESS_URL` from environment
- `gerrit_url` - Uses `GERRIT_URL` from environment

### 5. Template Deployment

The `template.sh` script deploys a VS Code workspace template:

**Features:**
- ✅ Copies Terraform template to container
- ✅ Authenticates with Coder CLI using `CODER_SESSION_TOKEN`
- ✅ Pushes template with proper configuration
- ✅ Handles token authentication gracefully
- ✅ Skips deployment if no token provided (with helpful message)

## 🔧 Troubleshooting

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

## Configuration Examples

### Gerrit Configuration

```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = http://127.0.0.1:3000
  apiKey = ${secret:coder/session_token}
  templateId = 2d0e2208-8b2d-4ea5-9ba1-44a68cc5d27f
  organization = 7daa7856-045c-4589-b4af-dee232d16bb3
  user = lemonjia
  autostart = true
  automaticUpdates = always
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

# Run complete setup
./run.sh
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
  user = YOUR_USERNAME
```

### 4. Test Integration
- Open a change in Gerrit
- Click "Open Coder Workspace" in the overflow menu
- Check browser console for any errors

## 🧹 Cleanup

```bash
# Stop Coder container
docker stop coder-server

# Remove Coder data (optional)
rm -rf ~/.config/coderv2-docker

# Clean up Terraform state (optional)
terraform destroy -auto-approve
```
