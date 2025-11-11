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

# Install Bazelisk (Bazel version manager)
RUN curl -Lo /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

# Install Bower (required for some plugins)
RUN npm install -g bower

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Set working directory
WORKDIR /build

# Clone Gerrit v3.4.1 with all plugins as submodules
# Using --recurse-submodules to automatically clone all plugin submodules
RUN git clone --branch v3.4.1 --recurse-submodules \
    https://gerrit.googlesource.com/gerrit.git gerrit

# Ensure all submodules are properly initialized and updated
WORKDIR /build/gerrit
RUN git submodule update --init --recursive

# Build Gerrit and plugins
# Build the release target which includes core plugins
RUN bazel build :release

# Extract the built war file
RUN cp bazel-bin/gerrit.war /build/gerrit.war

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

# Copy the built Gerrit war file from builder stage
COPY --from=builder /build/gerrit.war /var/gerrit/gerrit.war

# Create Gerrit site directory
RUN mkdir -p /var/gerrit/review_site && \
    chown -R gerrit:gerrit /var/gerrit

# Switch to gerrit user
USER gerrit

# Expose Gerrit ports
# 8080: HTTP
# 29418: SSH
EXPOSE 8080 29418

# Set environment variables
ENV GERRIT_SITE=/var/gerrit/review_site
ENV GERRIT_WAR=/var/gerrit/gerrit.war

# Default command: initialize Gerrit if not already initialized, then run
CMD if [ ! -f "$GERRIT_SITE/etc/gerrit.config" ]; then \
        java -jar $GERRIT_WAR init --batch --no-auto-start -d $GERRIT_SITE; \
    fi && \
    java -jar $GERRIT_WAR daemon -d $GERRIT_SITE
