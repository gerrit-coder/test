# Multi-stage Dockerfile for downloading and running Gerrit v3.4.1
# Stage 1: Download pre-built artifacts
FROM ubuntu:20.04 AS downloader

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install wget for downloading files
RUN apt-get update && apt-get install -y \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /downloads

# Download pre-built Gerrit 3.4.1 WAR file
RUN wget -O gerrit.war https://gerrit-releases.storage.googleapis.com/gerrit-3.4.1.war

# Download pre-built coder-workspace plugin JAR
RUN wget -O coder-workspace.jar https://github.com/gerrit-coder/plugins_coder-workspace/releases/download/v1.1.0-gerrit-3.4.1/coder-workspace-v1.1.0-gerrit-3.4.1.jar

# Stage 2: Runtime environment
# Using Eclipse Temurin (formerly AdoptOpenJDK) as openjdk images are deprecated
FROM eclipse-temurin:11-jre

# Install required runtime dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create gerrit user
RUN useradd -m -d /var/gerrit -s /bin/bash gerrit

# Set working directory
WORKDIR /var/gerrit

# Create Gerrit site directory and plugins directory
RUN mkdir -p /var/gerrit/review_site /var/gerrit/plugins

# Copy the pre-built Gerrit war file and plugin from downloader stage
COPY --from=downloader /downloads/gerrit.war /var/gerrit/gerrit.war
COPY --from=downloader /downloads/coder-workspace.jar /var/gerrit/plugins/coder-workspace.jar

# Set ownership
RUN chown -R gerrit:gerrit /var/gerrit

# Switch to gerrit user
USER gerrit

# Expose Gerrit ports
# 8080: HTTP
# 29418: SSH
EXPOSE 8080 29418

# Set environment variables
ENV GERRIT_SITE=/var/gerrit/review_site
ENV GERRIT_WAR=/var/gerrit/gerrit.war

# Default command
CMD if [ ! -f "$GERRIT_SITE/etc/gerrit.config" ]; then \
        java -jar $GERRIT_WAR init --batch --no-auto-start -d $GERRIT_SITE; \
    fi && \
    java -jar $GERRIT_WAR daemon -d $GERRIT_SITE
