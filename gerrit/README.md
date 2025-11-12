# Gerrit Test

This directory contains everything needed to deploy Gerrit v3.4.1 with the coder-workspace plugin using Docker Compose and the official Gerrit Docker image.

## 🚀 Quick Start

### Prerequisites

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 1.29 or later)

### First Time Setup

1. **Ensure gerrit.config exists**:
   The `etc/gerrit.config` file must exist in the `etc` subdirectory. If you don't have one, you can create it or copy from the example.

2. **Pull the Docker image** (downloads the official Gerrit image):
   ```bash
   ./gerrit.sh build
   ```

   **Note**: This uses `docker-compose pull` to pull the image specified in `docker-compose.yml` from Docker Hub. The image is ready to use and includes all necessary dependencies.

3. **Start Gerrit**:
   ```bash
   ./gerrit.sh run
   ```

   **Note**: The script will automatically download the coder-workspace plugin from GitHub releases if it doesn't already exist. The container will start with your `etc/gerrit.config` file and `plugins` directory bind-mounted. The `plugins` directory will be created automatically if it doesn't exist.

4. **Access Gerrit**:
   - Web UI: http://localhost:8080
   - SSH: ssh://localhost:29418

## 📖 Usage

### Using the Management Script

The `gerrit.sh` script provides a convenient interface for managing the Gerrit container:

```bash
# Pull the Docker image from docker-compose.yml
./gerrit.sh build

# Check if the Docker image exists
./gerrit.sh check-image

# Start the Gerrit container
./gerrit.sh run

# Check container status
./gerrit.sh status

# View container logs (follow mode)
./gerrit.sh logs

# Restart the container
./gerrit.sh restart

# Stop the container
./gerrit.sh stop

# Clean up: remove container and image
./gerrit.sh clean
```

### Using Docker Compose Directly

You can also use Docker Compose commands directly:

```bash
# Pull the image (optional, will be pulled automatically on up)
docker-compose -f docker-compose.yml pull

# Start services
docker-compose -f docker-compose.yml up -d

# View logs
docker-compose -f docker-compose.yml logs -f

# Stop services
docker-compose -f docker-compose.yml down

# Restart services
docker-compose -f docker-compose.yml restart
```

**Note**: The `gerrit.sh` script automatically reads the image name and container name from `docker-compose.yml`, so you can update these values in the compose file and the script will use them automatically.

## ⚙️ Configuration

### Initial Setup

On first run, Gerrit will be automatically initialized with default settings. The initialization is non-interactive and uses default values.

### Custom Configuration

The `etc/gerrit.config` file is **bind-mounted** from the local directory into the container. This means:
- The local `./etc/gerrit.config` file is directly mounted to `/var/gerrit/review_site/etc/gerrit.config` in the container
- Changes to the local file are immediately reflected in the container (after restart)
- The file must exist before starting the container

#### Editing the Configuration File

1. **Edit the local file**:
   ```bash
   # Edit ./etc/gerrit.config in your favorite editor
   nano etc/gerrit.config
   # or
   vim etc/gerrit.config
   ```

2. **Restart the container** to apply changes:
   ```bash
   ./gerrit.sh restart
   ```

#### Getting a Default Configuration

If you don't have a `etc/gerrit.config` file yet, you can:

1. **Let Gerrit initialize first** (temporarily comment out the bind mount in `docker-compose.yml`):
   ```bash
   # Comment out the gerrit.config bind mount in docker-compose.yml
   # Then start Gerrit
   ./gerrit.sh run

   # Create etc directory and copy the generated config
   mkdir -p etc
   docker cp gerrit:/var/gerrit/review_site/etc/gerrit.config ./etc/gerrit.config

   # Stop and uncomment the bind mount, then restart
   ./gerrit.sh stop

   # Uncomment the bind mount in docker-compose.yml
   ./gerrit.sh run
   ```

2. **Or use the provided example** if available in the repository.

### Plugins Directory

The `plugins` directory is **bind-mounted** from the local directory into the container. This means:
- The `plugins` directory is automatically created when you run `./gerrit.sh run` if it doesn't exist
- The **coder-workspace plugin is automatically downloaded** from GitHub releases when you run `./gerrit.sh run` if it doesn't already exist
- The plugin is saved as `coder-workspace.jar` in the local `./plugins` directory
- You can also manually place additional plugin JAR files in the `./plugins` directory
- All plugins in the directory will be available at `/var/gerrit/review_site/plugins/` in the container
- Plugins are automatically loaded by Gerrit on startup

**Plugin Download Details:**
- The script downloads the plugin from: `https://github.com/gerrit-coder/plugins_coder-workspace/releases`
- The plugin is saved as `plugins/coder-workspace.jar`
- If the plugin already exists, the download is skipped
- The download requires internet connectivity and either `curl` or `wget` to be installed

### Environment Variables

You can customize the setup by modifying `docker-compose.yml`:

```yaml
environment:
  - GERRIT_SITE=/var/gerrit/review_site
  - CANONICAL_WEB_URL=http://127.0.0.1:8080/
  # Add custom environment variables here
```

### Port Configuration

To change the exposed ports, edit `docker-compose.yml`:

```yaml
ports:
  - "8080:8080"   # Change first number to use different host port
  - "29418:29418" # Change first number to use different host port
```

## 🔧 Troubleshooting

### Image Pull Issues

**Problem**: Image pull fails with "Cannot reach hub.docker.com" error
- **Solution**: Check your internet connection. The Docker image pull requires internet access to download the official Gerrit image from Docker Hub

**Problem**: Image pull fails or times out
- **Solution**: Check your internet connection and firewall settings. The pull downloads the image specified in `docker-compose.yml` from Docker Hub. The image name is automatically read from the compose file.

**Problem**: Image pull is slow
- **Solution**: The first pull may take a few minutes depending on your network connection. Subsequent pulls will be faster if the image is already cached locally

### Runtime Issues

**Problem**: Container exits immediately
- **Solution**: Check logs with `./gerrit.sh logs` or `docker logs gerrit`

**Problem**: Cannot access Gerrit web UI
- **Solution**:
  1. Check if container is running: `./gerrit.sh status`
  2. Verify port 8080 is not in use: `netstat -tuln | grep 8080`
  3. Check firewall settings

**Problem**: Gerrit initialization fails
- **Solution**:
  1. Check logs for specific error messages
  2. Ensure Docker volumes have proper permissions
  3. Try removing volumes and reinitializing:
     ```bash
     ./gerrit.sh stop
     docker volume rm test_gerrit_site test_gerrit_cache
     ./gerrit.sh run
     ```

**Problem**: Container fails to start with "gerrit.config not found" error
- **Solution**: The local `./etc/gerrit.config` file doesn't exist. Fix by:
  1. Create the `etc` directory if it doesn't exist: `mkdir -p etc`
  2. Create or copy a `gerrit.config` file to the `etc` directory
  3. See the "Getting a Default Configuration" section above for instructions on obtaining a default config

**Problem**: Container fails to start with mount error "not a directory"
- **Solution**: This happens when `/var/gerrit/review_site/etc/gerrit.config` exists as a directory in the volume instead of a file. If you encounter this error:
  1. Stop all containers: `./gerrit.sh stop`
  2. Remove the volume and restart:
     ```bash
     ./gerrit.sh stop
     docker volume rm test_gerrit_site
     ./gerrit.sh run
     ```

### Plugin Issues

**Problem**: Plugin download fails
- **Solution**:
  1. Check internet connectivity: Ensure you can reach `https://github.com`
  2. Verify curl or wget is installed: `curl --version` or `wget --version`
  3. Check firewall/proxy settings that might block GitHub downloads
  4. Manually download the plugin:
     ```bash
     mkdir -p plugins
     curl -L -o plugins/coder-workspace.jar \
       https://github.com/gerrit-coder/plugins_coder-workspace/releases/download/v1.1.0-gerrit-3.4.1/coder-workspace-v1.1.0-gerrit-3.4.1.jar
     ```

**Problem**: coder-workspace plugin not loading
- **Solution**:
  1. Verify plugin JAR file exists: Check that `coder-workspace.jar` exists in the local `./plugins` directory
  2. Verify plugin is mounted: Check that the plugin appears in `/var/gerrit/review_site/plugins/` inside the container:
     ```bash
     docker exec gerrit ls -la /var/gerrit/review_site/plugins/
     ```
  3. Check Gerrit logs for plugin loading errors: `./gerrit.sh logs`
  4. Verify plugin version compatibility: The downloaded plugin version (v1.1.0-gerrit-3.4.1) is compatible with Gerrit v3.4.1
  5. Ensure the plugin is enabled in `./etc/gerrit.config`:
     ```
     [plugins]
       allowRemoteAdmin = true
     [plugin "coder-workspace"]
       enabled = true
     ```

## 🧹 Cleanup

### Using the Management Script

The easiest way to clean up:

```bash
# Clean up container and image
./gerrit.sh clean

# Remove volumes (WARNING: This deletes all Gerrit data!)
docker volume rm test_gerrit_site test_gerrit_cache
```

### Manual Cleanup

You can also clean up manually:

```bash
# Stop and remove containers
./gerrit.sh stop

# Remove volumes (WARNING: This deletes all Gerrit data!)
docker volume rm test_gerrit_site test_gerrit_cache

# Remove the Docker image (image name is read from docker-compose.yml)
# Check the image name first: ./gerrit.sh check-image
# Then remove it: docker rmi <image-name>
```

## 🔗 Related Documentation

- [Official Gerrit Docker Image](https://hub.docker.com/r/gerritcodereview/gerrit)
- [Gerrit Installation Guide](https://gerrit-review.googlesource.com/Documentation/install.html)
- [Gerrit Configuration](https://gerrit-review.googlesource.com/Documentation/config-gerrit.html)
- [Coder Workspace Plugin](https://github.com/gerrit-coder/plugins_coder-workspace)
