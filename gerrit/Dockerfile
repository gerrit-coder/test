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
# Using Ubuntu 20.04 with JDK
FROM ubuntu:20.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required runtime dependencies and tools for JDK installation
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Install OpenJDK 21 via apt
RUN apt-get update && \
    apt-get install -y openjdk-21-jdk && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME and update PATH
# OpenJDK installed via apt is typically at /usr/lib/jvm/java-21-openjdk-amd64
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Create gerrit user
RUN useradd -m -d /var/gerrit -s /bin/bash gerrit

# Set working directory
WORKDIR /var/gerrit

# Create Gerrit site directory and plugins directory
RUN mkdir -p /var/gerrit/review_site /var/gerrit/plugins /var/gerrit/review_site/etc

# Copy the pre-built Gerrit war file and plugin from downloader stage
COPY --from=downloader /downloads/gerrit.war /var/gerrit/gerrit.war
COPY --from=downloader /downloads/coder-workspace.jar /var/gerrit/plugins/coder-workspace.jar

# Copy gerrit.config file into the image
COPY gerrit.config /var/gerrit/review_site/etc/gerrit.config

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
CMD ["sh", "-c", \
    "if [ ! -f \"$GERRIT_SITE/etc/gerrit.config\" ]; then \
        java -jar $GERRIT_WAR init --batch --no-auto-start -d $GERRIT_SITE; \
    fi && \
    java -jar $GERRIT_WAR daemon -d $GERRIT_SITE"]
