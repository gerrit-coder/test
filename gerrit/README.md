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
  # Add custom environment variables here
```

### Port Configuration

To change the exposed ports, edit `docker-compose.yml`:

```yaml
ports:
  - "8080:8080"   # Change first number to use different host port
  - "29418:29418" # Change first number to use different host port
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
