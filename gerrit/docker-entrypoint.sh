#!/bin/bash
set -e

# Ensure the etc directory exists in the volume
mkdir -p "$GERRIT_SITE/etc"

# Ensure the logs directory exists (required for garbage collection log)
mkdir -p "$GERRIT_SITE/logs"

# If gerrit.config doesn't exist, run init
if [ ! -f "$GERRIT_SITE/etc/gerrit.config" ]; then
    echo "Initializing Gerrit site..."
    java -jar "$GERRIT_WAR" init --batch --no-auto-start -d "$GERRIT_SITE"
fi

# Start Gerrit daemon
exec java -jar "$GERRIT_WAR" daemon -d "$GERRIT_SITE"
