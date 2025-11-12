#!/bin/bash
set -e

# Fix permissions for directories that may have been created by init container as root
# This ensures the gerrit user can write to them
if [ -d "$GERRIT_SITE" ]; then
    chown -R gerrit:gerrit "$GERRIT_SITE" 2>/dev/null || true
fi

# Ensure the etc directory exists in the volume
mkdir -p "$GERRIT_SITE/etc"
chown gerrit:gerrit "$GERRIT_SITE/etc" 2>/dev/null || true

# Ensure the logs directory exists (required for garbage collection log)
mkdir -p "$GERRIT_SITE/logs"
chown gerrit:gerrit "$GERRIT_SITE/logs" 2>/dev/null || true

# If gerrit.config doesn't exist, run init as gerrit user
if [ ! -f "$GERRIT_SITE/etc/gerrit.config" ]; then
    echo "Initializing Gerrit site..."
    gosu gerrit java -jar "$GERRIT_WAR" init --batch --no-auto-start -d "$GERRIT_SITE"
fi

# Start Gerrit daemon as gerrit user
exec gosu gerrit java -jar "$GERRIT_WAR" daemon -d "$GERRIT_SITE"
