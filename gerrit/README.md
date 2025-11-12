# Gerrit v3.4.1 Docker Setup

This directory contains everything needed to deploy Gerrit v3.4.1 with the coder-workspace plugin using Docker Compose.

## 📋 Overview

This setup provides:
- **Multi-stage Docker image** based on Ubuntu 20.04 with OpenJDK 21
- **Pre-built artifacts** - downloads Gerrit v3.4.1 WAR and coder-workspace plugin JAR (no compilation required)
- **OpenJDK 21** - installed via apt package manager
- **Configuration file** - `etc/gerrit.config` is bind-mounted from the local directory into the container
- **Init container** - automatically creates required directory structure before the main container starts
- **Docker Compose** configuration for easy deployment
- **Management script** (`gerrit.sh`) for building the Docker image, running, and managing the container

## 🚀 Quick Start

### Prerequisites

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 1.29 or later)

### First Time Setup

1. **Ensure gerrit.config exists**:
   The `etc/gerrit.config` file must exist in the `etc` subdirectory. If you don't have one, you can create it or copy from the example.

2. **Build the Docker image** (downloads pre-built artifacts and installs OpenJDK 21, takes 2-5 minutes):
   ```bash
   ./gerrit.sh build
   ```

   **Note**: This downloads pre-built files (Gerrit WAR and plugin JAR) and installs OpenJDK 21 via apt - no compilation or building of source code is performed.

3. **Start Gerrit**:
   ```bash
   ./gerrit.sh run
   ```

   **Note**: The init container (`gerrit-init`) will run first to create the required directory structure in the volume, then the main Gerrit container will start with your `etc/gerrit.config` file bind-mounted.

4. **Access Gerrit**:
   - Web UI: http://localhost:8080
   - SSH: ssh://localhost:29418

## 📖 Usage

### Using the Management Script

The `gerrit.sh` script provides a convenient interface for managing the Gerrit container:

```bash
# Build the Docker image (downloads pre-built artifacts, uses cache for faster rebuilds)
./gerrit.sh build

# Build without cache (clean download, takes slightly longer)
./gerrit.sh build --no-cache

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

# Clean up: remove container, image, and build cache
./gerrit.sh clean
```

### Using Docker Compose Directly

You can also use Docker Compose commands directly:

```bash
# Build the image
docker-compose -f docker-compose.yml build

# Start services
docker-compose -f docker-compose.yml up -d

# View logs
docker-compose -f docker-compose.yml logs -f

# Stop services
docker-compose -f docker-compose.yml down

# Restart services
docker-compose -f docker-compose.yml restart
```

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

**Note**: The bind mount requires the `/etc` directory to exist in the volume. This is automatically handled by the `gerrit-init` init container that runs before the main container starts.

### Environment Variables

You can customize the setup by modifying `docker-compose.yml`:

```yaml
environment:
  - GERRIT_SITE=/var/gerrit/review_site
  - JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
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

### Build Issues

**Problem**: Build fails with "Cannot reach gerrit-releases.storage.googleapis.com" or "Cannot reach github.com" error
- **Solution**: Check your internet connection. The Docker image build requires internet access to download pre-built Gerrit WAR and plugin JAR

**Problem**: Download fails or times out
- **Solution**: Check your internet connection and firewall settings. The build downloads files from:
  - GitHub releases: `https://github.com/gerrit-coder/plugins_coder-workspace/releases`
  - Gerrit releases storage: `https://gerrit-releases.storage.googleapis.com`
  - Ubuntu package repositories (for OpenJDK 21 installation via apt)

**Problem**: Build fails with "out of memory" errors
- **Solution**: This is unlikely since no compilation occurs, but if it happens, increase Docker memory limit in Docker Desktop settings

**Problem**: Build is slow
- **Solution**: The build should take 2-5 minutes as it downloads pre-built artifacts (Gerrit WAR and plugin JAR) and installs OpenJDK 21 via apt. If it's slow, check your network connection. Subsequent builds will be faster due to Docker layer caching

**Problem**: Want to force a clean rebuild
- **Solution**: Use `./gerrit.sh build --no-cache` to force re-download of all artifacts

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
- **Solution**: This happens when `/var/gerrit/review_site/etc/gerrit.config` exists as a directory in the volume instead of a file. The init container now automatically removes any conflicting directory. If you still encounter this error:
  1. Stop all containers: `./gerrit.sh stop`
  2. Remove the init container so it runs again: `docker rm gerrit-init 2>/dev/null || true`
  3. Restart: `./gerrit.sh run` (the init container will remove the conflicting directory and recreate the structure)

  If the problem persists, remove the volume completely:
  ```bash
  ./gerrit.sh stop
  docker volume rm test_gerrit_site
  ./gerrit.sh run
  ```

### Plugin Issues

**Problem**: coder-workspace plugin not loading
- **Solution**:
  1. Verify plugin was downloaded: Check that `coder-workspace.jar` exists in `/var/gerrit/plugins/` inside the container
  2. Check Gerrit logs for plugin loading errors: `./gerrit.sh logs`
  3. Verify plugin version compatibility: The plugin version v1.1.0-gerrit-3.4.1 is compatible with Gerrit v3.4.1
  4. Ensure the plugin is enabled in `$GERRIT_SITE/etc/gerrit.config`:
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
# Clean up container, image, and build cache
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

# Remove the Docker image
docker rmi gerrit:3.4.1
```

## 📝 Notes

- **Base Image**: Ubuntu 20.04
- **Java Runtime**: OpenJDK 21 installed via apt package manager at `/usr/lib/jvm/java-21-openjdk-amd64`
- **Docker Image Build**: The Docker image build takes 2-5 minutes depending on your network speed (only downloads pre-built artifacts, no compilation)
- **Disk Space**: Ensure you have at least 3GB free space for the Docker image build (includes JDK download)
- **Memory**: Minimal memory requirements (no compilation or building of source code)
- **Gerrit WAR**: Pre-built Gerrit v3.4.1 WAR is downloaded from `https://gerrit-releases.storage.googleapis.com/gerrit-3.4.1.war`
- **Plugin**: Pre-built coder-workspace plugin v1.1.0-gerrit-3.4.1 is downloaded from GitHub releases: `https://github.com/gerrit-coder/plugins_coder-workspace/releases/download/v1.1.0-gerrit-3.4.1/coder-workspace-v1.1.0-gerrit-3.4.1.jar`
- **JDK**: OpenJDK 21 is installed via apt package manager (openjdk-21-jdk package)
- **No Building**: No source code is cloned or compiled - only pre-built artifacts are downloaded
- **Auto-Initialization**: Gerrit is automatically initialized on first run with default settings
- **Data Persistence**: Gerrit data is stored in Docker volumes and persists across container restarts
- **Plugin Location**: The plugin JAR is installed at `/var/gerrit/plugins/coder-workspace.jar` in the container
- **Configuration File**: The `etc/gerrit.config` file is **bind-mounted** from the local directory (`./etc/gerrit.config`) to `/var/gerrit/review_site/etc/gerrit.config` in the container. The file must exist before starting the container.
- **Init Container**: A `gerrit-init` container (using busybox) runs before the main container to create the required `/etc` directory structure in the volume, enabling the bind mount to work correctly.
- **Entrypoint Script**: The container uses `docker-entrypoint.sh` to ensure directory structure exists and handle Gerrit initialization if needed.

## 🔗 Related Documentation

- [Gerrit Installation Guide](https://gerrit-review.googlesource.com/Documentation/install.html)
- [Gerrit Configuration](https://gerrit-review.googlesource.com/Documentation/config-gerrit.html)
- [Coder Workspace Plugin](https://github.com/gerrit-coder/plugins_coder-workspace)

## 🆘 Getting Help

If you encounter issues:

1. Check the logs: `./gerrit.sh logs`
2. Verify container status: `./gerrit.sh status`
3. Review the troubleshooting section above
4. Check Gerrit documentation for configuration issues
