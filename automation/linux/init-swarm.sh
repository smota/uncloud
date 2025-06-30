#!/bin/bash

# UnCloud - Docker Swarm Initialization Script
# This script initializes the Docker Swarm infrastructure

set -e

# Default values
ENVIRONMENT=${1:-"production"}
FORCE=${2:-"false"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load configuration
CONFIG_PATH="$(dirname "$0")/../../config/common.env"
if [ -f "$CONFIG_PATH" ]; then
    echo "Loading configuration from $CONFIG_PATH"
    export $(grep -v '^#' "$CONFIG_PATH" | xargs)
fi

# Function to check if Docker is running
check_docker_running() {
    if ! docker version >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
}

# Function to create external networks
create_external_networks() {
    echo -e "${GREEN}Creating external networks...${NC}"
    
    networks=(
        "$FRONTEND_NETWORK"
        "$BACKEND_NETWORK"
        "$INFRASTRUCTURE_NETWORK"
    )
    
    for network in "${networks[@]}"; do
        if ! docker network ls --filter "name=$network" --format "{{.Name}}" | grep -q "$network"; then
            echo -e "${YELLOW}Creating network: $network${NC}"
            docker network create --driver overlay --attachable "$network"
        else
            echo -e "${CYAN}Network $network already exists${NC}"
        fi
    done
}

# Function to create external volumes
create_external_volumes() {
    echo -e "${GREEN}Creating external volumes...${NC}"
    
    volumes=(
        "$SHARED_DATA_VOLUME"
        "$SECRETS_VOLUME"
        "database_data"
        "traefik_data"
        "dns_data"
        "loadbalancer_data"
        "sync_data"
        "website_data"
        "email_data"
        "pwdmanager_data"
        "nas_data"
        "backup_data"
    )
    
    for volume in "${volumes[@]}"; do
        if ! docker volume ls --filter "name=$volume" --format "{{.Name}}" | grep -q "$volume"; then
            echo -e "${YELLOW}Creating volume: $volume${NC}"
            docker volume create "$volume"
        else
            echo -e "${CYAN}Volume $volume already exists${NC}"
        fi
    done
}

# Function to initialize Docker Swarm
initialize_docker_swarm() {
    echo -e "${GREEN}Initializing Docker Swarm...${NC}"
    
    swarm_state=$(docker info --format "{{.Swarm.LocalNodeState}}" 2>/dev/null || echo "inactive")
    
    if [ "$swarm_state" = "inactive" ]; then
        echo -e "${YELLOW}Initializing new Swarm...${NC}"
        docker swarm init
    elif [ "$swarm_state" = "active" ]; then
        echo -e "${CYAN}Swarm is already active${NC}"
    else
        echo -e "${YELLOW}Swarm status: $swarm_state${NC}"
    fi
}

# Function to validate secrets
validate_secrets_configuration() {
    echo -e "${GREEN}Validating secrets configuration...${NC}"
    
    secrets_path="$(dirname "$0")/../../secrets/.env"
    if [ ! -f "$secrets_path" ]; then
        echo -e "${RED}ERROR: Secrets file not found at $secrets_path${NC}"
        echo -e "${YELLOW}Please copy secrets/env.template to secrets/.env and configure your secrets${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Secrets file found and validated${NC}"
}

# Function to set up firewall rules (optional)
setup_firewall() {
    echo -e "${GREEN}Setting up firewall rules...${NC}"
    
    # Check if ufw is available
    if command -v ufw >/dev/null 2>&1; then
        echo -e "${YELLOW}Configuring UFW firewall...${NC}"
        # Allow SSH
        ufw allow ssh
        # Allow HTTP/HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        # Allow Docker Swarm ports
        ufw allow 2377/tcp
        ufw allow 7946/tcp
        ufw allow 7946/udp
        ufw allow 4789/udp
        # Enable firewall
        ufw --force enable
        echo -e "${GREEN}UFW firewall configured${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        echo -e "${YELLOW}Configuring firewalld...${NC}"
        # Allow HTTP/HTTPS
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        # Allow Docker Swarm ports
        firewall-cmd --permanent --add-port=2377/tcp
        firewall-cmd --permanent --add-port=7946/tcp
        firewall-cmd --permanent --add-port=7946/udp
        firewall-cmd --permanent --add-port=4789/udp
        # Reload firewall
        firewall-cmd --reload
        echo -e "${GREEN}Firewalld configured${NC}"
    else
        echo -e "${YELLOW}No supported firewall found. Please configure your firewall manually.${NC}"
    fi
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Docker Swarm Initialization ===${NC}"
echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"

# Check if Docker is running
check_docker_running

# Validate secrets
validate_secrets_configuration

# Initialize Swarm
initialize_docker_swarm

# Create networks
create_external_networks

# Create volumes
create_external_volumes

# Setup firewall (optional)
read -p "Do you want to configure firewall rules? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    setup_firewall
fi

echo -e "${GREEN}=== Initialization Complete ===${NC}"
echo -e "${CYAN}You can now run the deployment scripts:${NC}"
echo -e "${NC}  - deploy-all.sh (for single host deployment)${NC}"
echo -e "${NC}  - deploy-frontend.sh (for frontend-only deployment)${NC}"
echo -e "${NC}  - deploy-backend.sh (for backend-only deployment)${NC}" 