# Coder Test

This directory contains scripts and configuration files to set up a complete test environment for the Coder Workspace Gerrit plugin, including proper CORS configuration and Terraform-based workspace management.

## 🚀 Quick Start

### Option 1: Complete Automated Setup
```bash
# Copy environment template and customize
cp env.example .env
# Edit .env with your values

# Run complete setup (handles everything automatically)
./run.sh
```

### Option 1b: Nginx Proxy Setup (Recommended for CORS Issues)
```bash
# Copy environment template and customize
cp env.example .env
# Edit .env with your values

# Run nginx-based setup (handles CORS automatically)
./setup-nginx.sh
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
# Load environment variables
source ./load-env.sh

# Apply environment variables to configuration files
./apply-env-to-yaml.sh

# Start Coder server
./coder.sh

# Setup CORS configuration
./setup-cors.sh

# Deploy template
./template.sh

# Test CORS configuration
./test-cors.sh
```

## 📋 Environment Variables

Configure the test environment using these environment variables (set in `.env` file):

| Variable | Description | Default |
|----------|-------------|---------|
| `GERRIT_URL` | Gerrit server URL | `http://127.0.0.1:8080` |
| `CODER_PORT` | Coder server port | `3000` |
| `CODER_ACCESS_URL` | External Coder URL | `http://127.0.0.1:3000` |
| `CODER_URL` | Internal Coder URL for CLI | `http://127.0.0.1:3000` |
| `NGINX_PORT` | Nginx proxy port | `3001` |
| `CODER_PROXY_URL` | Nginx proxy URL for Gerrit | `http://127.0.0.1:3001` |
| `CODER_TEMPLATE_NAME` | Template name | `vscode-web` |
| `DOCKER_GROUP` | Docker group ID for permissions | *(required for docker-compose)* |
| `CODER_DATA` | Coder data directory for persistence | `./coder-data` |
| `CODER_HTTP_ADDRESS` | Coder HTTP binding address | `0.0.0.0:3000` |
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

# Docker Configuration (required for docker-compose.yml)
# Get the Docker group ID by running: getent group docker | cut -d: -f3
DOCKER_GROUP="999"

# Coder Data Directory (for persistence)
CODER_DATA="./coder-data"

# Coder HTTP Binding (for Docker networking)
CODER_HTTP_ADDRESS="0.0.0.0:3000"

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
| **`setup-nginx.sh`** | Nginx proxy setup for CORS (recommended for CORS issues) |
| **`setup-terraform.sh`** | Terraform-based setup with CORS |
| **`load-env.sh`** | Loads environment variables from .env file |

### 🔧 Configuration Scripts

| Script | Description |
|--------|-------------|
| **`apply-env-to-yaml.sh`** | Applies environment variables to YAML files |
| **`env-to-terraform.sh`** | Converts .env to terraform.tfvars |
| **`coder.sh`** | Starts Coder server with Docker |
| **`setup-cors.sh`** | Configures CORS settings for Gerrit integration |
| **`template.sh`** | Deploys the VS Code template to Coder |
| **`test-cors.sh`** | Tests CORS configuration |

### 📋 Configuration Files

| File | Description |
|------|-------------|
| **`.env`** | Environment variables (copy from env.example) |
| **`env.example`** | Environment variables template |
| **`coder.yaml`** | Coder server configuration with CORS settings |
| **`coder-explicit.yaml`** | Explicit CORS configuration (no env vars) |
| **`nginx.conf`** | Nginx reverse proxy configuration for CORS |
| **`docker-compose.yml`** | Docker Compose configuration for Coder + Nginx |
| **`code-server.tf`** | Terraform template for VS Code workspace |
| **`terraform.tfvars`** | Terraform variables (generated from .env) |

## 🏗️ Detailed Setup

### 🔗 URL Configuration Guide

The test environment provides two ways to connect Gerrit to Coder:

**Option 1: Nginx Proxy (Recommended)**
- **Gerrit Plugin Configuration**: `serverUrl = http://localhost:3001`
- **Environment Variable**: `CODER_PROXY_URL="http://127.0.0.1:3001"`
- **Benefits**: Automatic CORS handling, no Coder configuration needed
- **Setup**: Run `./setup-nginx.sh`

**Option 2: Direct Coder Connection**
- **Gerrit Plugin Configuration**: `serverUrl = http://localhost:3000`
- **Environment Variable**: `CODER_ACCESS_URL="http://127.0.0.1:3000"`
- **Benefits**: Direct connection, simpler setup
- **Requirements**: Coder must be configured with proper CORS settings
- **Setup**: Run `./run.sh` or `./setup-cors.sh`

**For Production:**
- Replace `localhost` with your actual server hostnames
- Use HTTPS URLs for production environments
- Configure proper DNS and SSL certificates

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
- CORS configuration for Gerrit integration
- External access on configurable port
- Proper volume mounts for persistence

**Environment Variables:**
- `CODER_PORT` - Coder server port (default: 3000)
- `CODER_ACCESS_URL` - External URL for Coder
- `CODER_URL` - Internal URL for CLI
- `CODER_TEMPLATE_NAME` - Template name (default: vscode-web)

### 3. Nginx Proxy Solution (Recommended)

The `setup-nginx.sh` script provides a robust solution for CORS issues by using nginx as a reverse proxy:

**Features:**
- ✅ Handles all CORS headers automatically
- ✅ No need to configure Coder CORS settings
- ✅ Works with any Gerrit URL configuration
- ✅ Supports WebSocket connections
- ✅ Health check endpoint for monitoring
- ✅ Docker Compose-based deployment

**Architecture:**
```
Gerrit (8080) → Nginx Proxy (3001) → Coder (3000)
```

**Configuration:**
- Gerrit plugin uses `serverUrl = http://localhost:3001` (nginx proxy)
- Nginx proxy forwards requests to Coder on port 3000
- All CORS headers are handled by nginx
- Use `CODER_PROXY_URL` environment variable for flexible configuration

**Files:**
- `nginx.conf` - Nginx configuration with CORS headers
- `docker-compose.yml` - Docker Compose setup for both services
- `setup-nginx.sh` - Automated setup script
- `test-nginx-cors.sh` - Testing script for nginx proxy

### 4. CORS Configuration (Alternative)

The `setup-cors.sh` script handles CORS setup directly in Coder:

**Features:**
- ✅ Validates Coder container is running
- ✅ Uses reliable docker inspect-based running check
- ✅ Updates CORS configuration with `GERRIT_URL` from environment
- ✅ Applies configuration and restarts Coder
- ✅ Tests CORS preflight requests
- ✅ Verifies API accessibility

**CORS Settings:**
```yaml
http:
  cors:
    allow_origins:
      - "${GERRIT_URL:-http://127.0.0.1:8080}"  # Uses environment variable
      - "http://127.0.0.1:8080"    # Local development fallback
    allow_methods:
      - GET, POST, DELETE, OPTIONS
    allow_headers:
      - Content-Type
      - Coder-Session-Token
      - Authorization
      - Accept
    allow_credentials: true
    enabled: true
```

### 5. Terraform Integration

The `code-server.tf` file includes:
- Environment variable support for all CORS settings
- Docker container configuration with proper environment variables
- Flexible configuration via Terraform variables
- Fixed Docker command to ensure workspace container starts reliably

**Terraform Variables:**
- `coder_cors_allow_origins` - Uses `GERRIT_URL` from environment
- `coder_cors_allow_methods` - Configurable HTTP methods
- `coder_cors_allow_headers` - Configurable headers
- `coder_access_url` - Uses `CODER_ACCESS_URL` from environment
- `gerrit_url` - Uses `GERRIT_URL` from environment

### 6. Template Deployment

The `template.sh` script deploys a VS Code workspace template:

**Features:**
- ✅ Copies Terraform template to container
- ✅ Authenticates with Coder CLI using `CODER_SESSION_TOKEN`
- ✅ Pushes template with proper configuration
- ✅ Handles token authentication gracefully
- ✅ Skips deployment if no token provided (with helpful message)

## 🔧 Troubleshooting

### Nginx Proxy Issues

If you're using the nginx proxy solution and experiencing issues:

```bash
# Check if containers are running
docker ps | grep -E "(coder-server|nginx-coder-proxy)"

# Check nginx logs
docker logs nginx-coder-proxy

# Check coder logs
docker logs coder-server

# Test nginx proxy directly
curl -v http://localhost:3001/health

# Test CORS through nginx
./test-nginx-cors.sh
```

**Common Issues:**
- **Container not starting**: Check Docker is running and ports 3000/3001 are available
- **CORS still failing**: Ensure Gerrit plugin uses `serverUrl = http://localhost:3001`
- **Connection refused**: Wait for services to fully start (can take 30+ seconds)

### CORS Issues

If you see CORS errors in browser console:
```bash
# Test CORS configuration using environment variables
curl -H "Origin: ${GERRIT_URL:-http://127.0.0.1:8080}" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: Coder-Session-Token" \
     -X OPTIONS \
     http://127.0.0.1:${CODER_PORT:-3000}/api/v2/templates
```

**Expected response:** HTTP 200 with CORS headers:
```
Access-Control-Allow-Origin: http://your-gerrit-server:8080
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Coder-Session-Token, Authorization, Accept
Access-Control-Allow-Credentials: true
```

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
http:
  cors:
    allow_origins:
      - "http://127.0.0.1:8080"
    allow_methods:
      - GET
      - POST
      - DELETE
      - OPTIONS
    allow_headers:
      - Content-Type
      - Coder-Session-Token
```

## 🚀 Development Workflow

### 1. Initial Setup (Nginx Proxy - Recommended)
```bash
# Copy environment template
cp env.example .env

# Edit .env with your values
nano .env

# Run nginx-based setup
./setup-nginx.sh
```

### 1b. Initial Setup (Direct CORS)
```bash
# Copy environment template
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

**Option A: Using Nginx Proxy (Recommended)**
```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = http://localhost:3001  # Use nginx proxy port
  apiKey = ${secret:coder/session_token}
  templateId = YOUR_TEMPLATE_ID
  organization = YOUR_ORGANIZATION_ID
  user = YOUR_USERNAME
```

**Option B: Direct Coder Connection**
```ini
[plugin "coder-workspace"]
  enabled = true
  serverUrl = http://localhost:3000  # Direct coder port
  apiKey = ${secret:coder/session_token}
  templateId = YOUR_TEMPLATE_ID
  organization = YOUR_ORGANIZATION_ID
  user = YOUR_USERNAME
```

### 4. Test Integration
- Open a change in Gerrit
- Click "Open Coder Workspace" in the overflow menu
- Check browser console for any errors

## 🧹 Cleanup

```bash
# Stop services (nginx proxy setup)
docker-compose down

# Stop Coder container (direct setup)
docker stop coder-server

# Remove Coder data (optional)
rm -rf ~/.config/coderv2-docker

# Clean up Terraform state (optional)
terraform destroy -auto-approve
```
