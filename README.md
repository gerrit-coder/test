# Coder Test

This directory contains scripts and configuration files to set up a complete test environment for the Coder Workspace Gerrit plugin, including proper CORS configuration.

## Environment Variables

Configure the test environment using these environment variables:

- `GERRIT_URL` - Gerrit server URL (default: http://127.0.0.1:8080)
- `CODER_PORT` - Coder server port (default: 3000)
- `CODER_ACCESS_URL` - External Coder URL (default: http://127.0.0.1:$CODER_PORT)
- `CODER_URL` - Internal Coder URL for CLI (default: http://127.0.0.1:$CODER_PORT)
- `CODER_TEMPLATE_NAME` - Template name (default: vscode-web)
- `CODER_SESSION_TOKEN` - Coder API token for authentication

## Quick Start

1. **Start Coder server**
   ```bash
   # Set environment variables
   # Or Load environment variables from .env file
   # source ./load-env.sh
   export GERRIT_URL="http://your-gerrit-server:8080"
   export CODER_PORT="3000"
   export CODER_SESSION_TOKEN="your-coder-token"

   # Start Coder server with CORS configuration
   ./coder.sh

   # Configure CORS for Gerrit integration
   ./setup-cors.sh

   # Deploy the VS Code template
   ./template.sh
   ```

2. **Configure Gerrit plugin**
   ```ini
   [plugin "coder-workspace"]
     enabled = true
     serverUrl = http://127.0.0.1:3000
     apiKey = YOUR_CODER_SESSION_TOKEN
     templateId = YOUR_TEMPLATE_ID
     organization = YOUR_ORGANIZATION_ID
     user = YOUR_USERNAME
   ```

## Files Overview

### Core Scripts

- **`coder.sh`** - Starts Coder server with Docker, includes CORS configuration
- **`setup-cors.sh`** - Configures CORS settings for Gerrit integration
- **`template.sh`** - Deploys the VS Code template to Coder
- **`test-cors.sh`** - Tests CORS configuration
- **`load-env.sh`** - Loads environment variables from .env file

### Configuration Files

- **`coder.yaml`** - Coder server configuration with CORS settings
- **`code-server.tf`** - Terraform template for VS Code workspace
- **`env.example`** - Environment variables template

## Detailed Setup

### 1. Coder Server Setup

The `coder.sh` script starts a Coder server with:
- Docker-based deployment
- CORS configuration for Gerrit integration
- External access on port 3000
- Proper volume mounts for persistence

**Environment Variables:**
- `CODER_PORT` - Coder server port (default: 3000)
- `CODER_ACCESS_URL` - External URL for Coder (default: http://127.0.0.1:$CODER_PORT)
- `CODER_URL` - Internal URL for CLI (default: http://127.0.0.1:$CODER_PORT)
- `CODER_TEMPLATE_NAME` - Template name (default: vscode-web)

### 2. CORS Configuration

The `setup-cors.sh` script handles CORS setup:

**Features:**
- ✅ Validates Coder container is running
- ✅ Updates CORS configuration with Gerrit URL
- ✅ Applies configuration and restarts Coder
- ✅ Tests CORS preflight requests
- ✅ Verifies API accessibility (accepts HTTP 401 as valid response)

**CORS Settings:**
```yaml
http:
  cors:
    allow_origins:
      - "${GERRIT_URL:-http://127.0.0.1:8080}"  # Gerrit server
      - "http://127.0.0.1:8080"    # Local development fallback
    allow_methods:
      - GET, POST, DELETE, OPTIONS
    allow_headers:
      - Content-Type
      - Coder-Session-Token
```

### 3. Template Deployment

The `template.sh` script deploys a VS Code workspace template:

**Features:**
- ✅ Copies Terraform template to container
- ✅ Authenticates with Coder CLI
- ✅ Pushes template with proper configuration
- ✅ Handles token authentication gracefully
- ✅ Skips deployment if no token provided (with helpful message)

## Troubleshooting

### CORS Issues

If you see CORS errors in browser console:
```bash
# Test CORS configuration
curl -H "Origin: ${GERRIT_URL:-http://127.0.0.1:8080}" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS \
     http://127.0.0.1:${CODER_PORT:-3000}/api/v2/templates
```

**Expected response:** HTTP 200 with CORS headers (or HTTP 401 if not authenticated)

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

## Development Workflow

1. **Start test environment:**
   ```bash
   source ./load-env.sh
   ./coder.sh
   ./setup-cors.sh
   ./template.sh
   ```

2. **Get configuration values:**
   ```bash
   # Get organization ID
   curl -H "Coder-Session-Token: YOUR_TOKEN" \
        http://127.0.0.1:${CODER_PORT:-3000}/api/v2/organizations

   # Get template ID
   curl -H "Coder-Session-Token: YOUR_TOKEN" \
        http://127.0.0.1:${CODER_PORT:-3000}/api/v2/templates
   ```

3. **Configure Gerrit plugin** with obtained values

4. **Test integration** by clicking "Open Coder Workspace" in Gerrit

## Cleanup

```bash
# Stop Coder container
docker stop coder-server

# Remove Coder data (optional)
rm -rf ~/.config/coderv2-docker
```

## Support

For issues with this test environment:
1. Check container logs: `docker logs coder-server`
2. Verify CORS configuration: `./setup-cors.sh`
3. Test API connectivity: `curl http://127.0.0.1:${CODER_PORT:-3000}/api/v2/templates`
4. Check browser console for JavaScript errors
