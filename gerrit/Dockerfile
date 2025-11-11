# Multi-stage Dockerfile for building and running Gerrit v3.4.1
# Stage 1: Build environment
FROM ubuntu:20.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    python3 \
    python3-pip \
    curl \
    wget \
    git \
    zip \
    unzip \
    gcc \
    g++ \
    make \
    nodejs \
    npm \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Install Bazelisk
RUN curl -Lo /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Set working directory
WORKDIR /build

# Clone Gerrit source (needed for plugin build context, but not building Gerrit)
RUN git clone --recurse-submodules https://gerrit.googlesource.com/gerrit

# Ensure all submodules are properly initialized and updated
WORKDIR /build/gerrit
RUN git checkout --recurse-submodules v3.4.1

# Clone coder-workspace plugin into plugins directory
RUN git clone https://github.com/gerrit-coder/plugins_coder-workspace.git plugins/coder-workspace -b gerrit-3.4.1

# Build only the coder-workspace plugin
RUN bazel build plugins/coder-workspace:coder-workspace

# Copy the built plugin JAR
RUN cp bazel-bin/plugins/coder-workspace/coder-workspace.jar /build/coder-workspace.jar

# Download pre-built Gerrit 3.4.1 WAR file
WORKDIR /build
RUN wget -O gerrit.war https://gerrit-releases.storage.googleapis.com/gerrit-3.4.1.war

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

# Copy the pre-built Gerrit war file and plugin from builder stage
COPY --from=builder /build/gerrit.war /var/gerrit/gerrit.war
COPY --from=builder /build/coder-workspace.jar /var/gerrit/plugins/coder-workspace.jar

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
