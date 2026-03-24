#!/bin/bash

set -euo pipefail

# =============================================================================
# Proxy Configuration (EDIT if needed)
# =============================================================================
export http_proxy="http://proxy.bgl1.global.tslabs.hpecorp.net:8080"
export https_proxy="http://proxy.bgl1.global.tslabs.hpecorp.net:8080"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="localhost,127.0.0.1"

# =============================================================================
# Colour helpers
# =============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Inputs
# =============================================================================
echo ""
echo "============================================================"
echo "   Ubuntu Pre-Requisites Setup — Ansible + Git + Logstash   "
echo "============================================================"
echo ""

read -p "Enter GitHub username: " USERNAME
read -p "Enter Git URL (example: github.hpe.com): " MACHINE
read -s -p "Enter GitHub token: " TOKEN
echo
read -p "Enter Logstash version (example: 8.12.0): " LOGSTASH_VERSION

# Validate input
if [ -z "$LOGSTASH_VERSION" ]; then
    error "Logstash version cannot be empty"
    exit 1
fi

MAJOR_VERSION="${LOGSTASH_VERSION%%.*}"

# =============================================================================
# STEP 1 — Update system
# =============================================================================
info "Updating apt package index..."
sudo -E apt-get update -y
success "Package index updated."

# =============================================================================
# STEP 2 — Install base packages
# =============================================================================
info "Installing prerequisite packages..."
sudo -E apt-get install -y \
    software-properties-common \
    apt-transport-https \
    curl \
    gnupg \
    ca-certificates
success "Prerequisites installed."

# =============================================================================
# STEP 3 — Install Ansible (idempotent)
# =============================================================================
if command -v ansible >/dev/null 2>&1; then
    success "Ansible already installed. Skipping."
else
    info "Adding Ansible PPA..."
    sudo -E add-apt-repository --yes --update ppa:ansible/ansible

    info "Installing Ansible..."
    sudo -E apt-get install -y ansible
    success "Ansible installed."
fi

# =============================================================================
# STEP 4 — Install Git
# =============================================================================
if command -v git >/dev/null 2>&1; then
    success "Git already installed. Skipping."
else
    info "Installing Git..."
    sudo -E apt-get install -y git
    success "Git installed."
fi

# =============================================================================
# STEP 5 — Install Java
# =============================================================================
if java -version >/dev/null 2>&1; then
    success "Java already installed. Skipping."
else
    info "Installing OpenJDK 17..."
    sudo -E apt-get install -y openjdk-17-jdk
    success "Java installed."
fi

# =============================================================================
# STEP 6 — GitHub Auth (.netrc)
# =============================================================================
info "Creating ~/.netrc..."
cat <<EOF > ~/.netrc
machine $MACHINE
login $USERNAME
password $TOKEN
EOF
chmod 600 ~/.netrc
success ".netrc configured."

# =============================================================================
# STEP 7 — Elastic GPG Key (robust)
# =============================================================================
KEY_FILE="/tmp/elastic.key"
KEYRING="/usr/share/keyrings/elastic-keyring.gpg"
REPO_FILE="/etc/apt/sources.list.d/elastic-${MAJOR_VERSION}.x.list"

if [ -f "$KEYRING" ] && [ -s "$KEYRING" ]; then
    success "Elastic GPG key already exists. Skipping."
else
    info "Downloading Elastic GPG key..."

    if curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch -o "$KEY_FILE"; then
        
        if grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$KEY_FILE"; then
            sudo gpg --dearmor -o "$KEYRING" "$KEY_FILE"
            sudo chmod 644 "$KEYRING"
            rm -f "$KEY_FILE"
            success "Elastic GPG key added."
        else
            error "Invalid GPG key content (proxy issue likely)."
            exit 1
        fi

    else
        error "Failed to download Elastic GPG key."
        exit 1
    fi
fi

# =============================================================================
# STEP 8 — Elastic Repo
# =============================================================================
if [ -f "$REPO_FILE" ] && grep -q "artifacts.elastic.co" "$REPO_FILE"; then
    success "Elastic repo already configured. Skipping."
else
    info "Adding Elastic ${MAJOR_VERSION}.x repo..."

    echo "deb [signed-by=${KEYRING}] https://artifacts.elastic.co/packages/${MAJOR_VERSION}.x/apt stable main" \
        | sudo tee "$REPO_FILE" > /dev/null

    success "Elastic repo added."
fi

sudo -E apt-get update -y

# =============================================================================
# STEP 9 — Download Logstash
# =============================================================================
DEB_FILE="logstash-${LOGSTASH_VERSION}-amd64.deb"
DEST="/tmp/${DEB_FILE}"

info "Cleaning old Logstash files..."
rm -f /tmp/logstash-*.deb

info "Downloading Logstash ${LOGSTASH_VERSION}..."
curl -fSL --progress-bar -o "$DEST" \
    "https://artifacts.elastic.co/downloads/logstash/${DEB_FILE}"

if [ -f "$DEST" ]; then
    success "Logstash downloaded: $DEST"
else
    error "Download failed."
    exit 1
fi

info "Configuring Git proxy..."
git config --global http.proxy "$http_proxy"
git config --global https.proxy "$https_proxy"
success "Git proxy configured."

# =============================================================================
# STEP 10 — Validation
# =============================================================================
echo ""
echo "==================== SUMMARY ===================="
echo "Ansible: $(ansible --version | head -1)"
echo "Git:     $(git --version)"
echo "Java:    $(java -version 2>&1 | head -1)"
echo "Deb:     $DEST"
echo "================================================"
echo ""

echo "Next step:"
echo "ansible-pull -U https://${MACHINE}/your-org/your-repo.git"
echo ""
