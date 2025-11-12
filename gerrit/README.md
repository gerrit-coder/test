# Gerrit v3.4.1 Docker Setup

This directory contains everything needed to deploy Gerrit v3.4.1 with the coder-workspace plugin using Docker Compose.

## 📋 Overview

This setup provides:
- **Multi-stage Docker image** based on Ubuntu 20.04 with JDK 21.0.5
- **Pre-built artifacts** - downloads Gerrit v3.4.1 WAR, coder-workspace plugin JAR, and JDK 21.0.5 (no compilation required)
- **Configuration file** - `gerrit.config` is included in the image and can be overridden via volume mount
- **Docker Compose** configuration for easy deployment
- **Management script** (`gerrit.sh`) for building the Docker image, running, and managing the container

## 🚀 Quick Start

### Prerequisites

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 1.29 or later)

### First Time Setup

1. **Build the Docker image** (downloads pre-built artifacts including JDK 21.0.5, takes 2-5 minutes):
   ```bash
   ./gerrit.sh build
   ```

   **Note**: This downloads pre-built files (Gerrit WAR, plugin JAR, and JDK 21.0.5) - no compilation or building of source code is performed.

2. **Start Gerrit**:
   ```bash
   ./gerrit.sh run
   ```

3. **Access Gerrit**:
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

The `gerrit.config` file is included in the Docker image and can be overridden by mounting a local file. You can customize Gerrit configuration in two ways:

#### Option 1: Edit Local Configuration File (Recommended)

1. **First-time setup**: The `gerrit.config` file is already included in the Docker image. If you want to customize it:
   ```bash
   # Start Gerrit to let it initialize (uses config from image)
   ./gerrit.sh run

   # Copy the config from container to local file for editing
   docker cp gerrit:/var/gerrit/review_site/etc/gerrit.config ./gerrit.config

   # Stop the container
   ./gerrit.sh stop
   ```

2. **Edit the local file**:
   ```bash
   # Edit ./gerrit.config in your favorite editor
   nano gerrit.config
   # or
   vim gerrit.config
   ```

3. **Restart the container** to apply changes:
   ```bash
   ./gerrit.sh restart
   ```

The local `./gerrit.config` file (if it exists) is automatically mounted to `/var/gerrit/review_site/etc/gerrit.config` in the container, overriding the image's default config. Your changes take effect immediately after restart.

#### Option 2: Edit Configuration in Volume

1. **Stop the container**:
   ```bash
   ./gerrit.sh stop
   ```

2. **Access the Gerrit site volume**:
   ```bash
   docker volume inspect test_gerrit_site
   ```

3. **Edit configuration files** directly in the volume:
   - Main config: `$GERRIT_SITE/etc/gerrit.config`
   - Secure config: `$GERRIT_SITE/etc/secure.config`

4. **Restart the container**:
   ```bash
   ./gerrit.sh restart
   ```

**Note**: The local `./gerrit.config` file takes precedence over the volume-mounted file. If you want to use the volume-based approach, temporarily comment out the `gerrit.config` volume mapping in `docker-compose.yml`.

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

## 🔧 Troubleshooting

### Build Issues

**Problem**: Build fails with "Cannot reach gerrit-releases.storage.googleapis.com" or "Cannot reach github.com" error
- **Solution**: Check your internet connection. The Docker image build requires internet access to download pre-built Gerrit WAR and plugin JAR

**Problem**: Download fails or times out
- **Solution**: Check your internet connection and firewall settings. The build downloads files from:
  - GitHub releases: `https://github.com/gerrit-coder/plugins_coder-workspace/releases`
  - Gerrit releases storage: `https://gerrit-releases.storage.googleapis.com`
  - Eclipse Temurin (Adoptium): `https://github.com/adoptium/temurin21-binaries/releases` (for JDK 21.0.5)

**Problem**: Build fails with "out of memory" errors
- **Solution**: This is unlikely since no compilation occurs, but if it happens, increase Docker memory limit in Docker Desktop settings

**Problem**: Build is slow
- **Solution**: The build should take 2-5 minutes as it downloads pre-built artifacts (Gerrit WAR, plugin JAR, and JDK 21.0.5). If it's slow, check your network connection. Subsequent builds will be faster due to Docker layer caching

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

**Problem**: Container fails to start with "gerrit.config is a directory" error
- **Solution**: The local `./gerrit.config` file doesn't exist, so Docker created it as a directory. Fix by:
  1. Remove the directory: `rm -rf ./gerrit.config`
  2. Let Gerrit initialize first (comment out the gerrit.config volume line in docker-compose.yml temporarily)
  3. Copy the generated config: `docker cp gerrit:/var/gerrit/review_site/etc/gerrit.config ./gerrit.config`
  4. Re-enable the volume mapping and restart

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
- **Java Runtime**: JDK 21.0.5 (Eclipse Temurin/OpenJDK) installed at `/opt/jdk-21.0.5`
- **Docker Image Build**: The Docker image build takes 2-5 minutes depending on your network speed (only downloads pre-built artifacts, no compilation)
- **Disk Space**: Ensure you have at least 3GB free space for the Docker image build (includes JDK download)
- **Memory**: Minimal memory requirements (no compilation or building of source code)
- **Gerrit WAR**: Pre-built Gerrit v3.4.1 WAR is downloaded from `https://gerrit-releases.storage.googleapis.com/gerrit-3.4.1.war`
- **Plugin**: Pre-built coder-workspace plugin v1.1.0-gerrit-3.4.1 is downloaded from GitHub releases: `https://github.com/gerrit-coder/plugins_coder-workspace/releases/download/v1.1.0-gerrit-3.4.1/coder-workspace-v1.1.0-gerrit-3.4.1.jar`
- **JDK**: JDK 21.0.5 is downloaded from Eclipse Temurin (Adoptium) releases
- **No Building**: No source code is cloned or compiled - only pre-built artifacts are downloaded
- **Auto-Initialization**: Gerrit is automatically initialized on first run with default settings
- **Data Persistence**: Gerrit data is stored in Docker volumes and persists across container restarts
- **Plugin Location**: The plugin JAR is installed at `/var/gerrit/plugins/coder-workspace.jar` in the container
- **Configuration File**: The `gerrit.config` file is included in the Docker image at build time and can be overridden by mounting a local `./gerrit.config` file. See the Configuration section for setup instructions.

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
