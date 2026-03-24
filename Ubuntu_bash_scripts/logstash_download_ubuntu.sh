#!/bin/bash

set -euo pipefail

# =============================================================================
# Proxy Configuration (EDIT as needed)
# =============================================================================
PROXY="http://proxy.bgl1.global.tslabs.hpecorp.net:8080"

export http_proxy="$PROXY"
export https_proxy="$PROXY"
export HTTP_PROXY="$PROXY"
export HTTPS_PROXY="$PROXY"

# Optional: exclude local traffic
export no_proxy="localhost,127.0.0.1"

# =============================================================================
# Colour helpers
# =============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Take input
# =============================================================================
read -p "Enter Logstash version (example: 9.3.1): " LOGSTASH_VERSION

# Validate input
if [ -z "$LOGSTASH_VERSION" ]; then
    error "Logstash version cannot be empty"
    exit 1
fi

# =============================================================================
# Variables
# =============================================================================
DEB_FILE="logstash-${LOGSTASH_VERSION}-amd64.deb"
DEST="/tmp/${DEB_FILE}"
URL="https://artifacts.elastic.co/downloads/logstash/${DEB_FILE}"

# =============================================================================
# Cleanup
# =============================================================================
info "Removing old Logstash files..."
rm -f /tmp/logstash-*.deb

# =============================================================================
# Download
# =============================================================================
info "Downloading Logstash ${LOGSTASH_VERSION}..."
info "Using proxy: $PROXY"
info "URL: ${URL}"

if curl -fSL --progress-bar -o "$DEST" "$URL"; then
    success "Download completed."
else
    error "Download failed. Check proxy/network or version."
    exit 1
fi

# =============================================================================
# Verification
# =============================================================================
if [ -f "$DEST" ] && [ -s "$DEST" ]; then
    FILE_SIZE=$(du -h "$DEST" | cut -f1)
    success "Logstash downloaded: $DEST (${FILE_SIZE})"
else
    error "Downloaded file is missing or empty."
    exit 1
fi
