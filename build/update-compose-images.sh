#!/bin/bash

# UnCloud - Update Compose Images Script
# This script updates docker-compose files to use built images

set -e

# Default values
REGISTRY=${1:-"uncloud"}
TAG=${2:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load configuration
CONFIG_PATH="$(dirname "$0")/../config/common.env"
if [ -f "$CONFIG_PATH" ]; then
    echo "Loading configuration from $CONFIG_PATH"
    export $(grep -v '^#' "$CONFIG_PATH" | xargs)
fi

# Function to update image in docker-compose file
update_compose_image() {
    local compose_file="$1"
    local service_name="$2"
    local new_image="$3"
    
    if [ -f "$compose_file" ]; then
        echo -e "${GREEN}Updating $service_name in $compose_file...${NC}"
        
        # Create backup
        cp "$compose_file" "$compose_file.backup"
        
        # Replace dummy image with built image
        sed -i "s|image: dummy/$service_name:[^[:space:]]*|image: $new_image|g" "$compose_file"
        
        # Check if file was modified
        if ! cmp -s "$compose_file" "$compose_file.backup"; then
            echo -e "${GREEN}✓ Updated $service_name to use $new_image${NC}"
        else
            echo -e "${YELLOW}⚠ No changes needed for $service_name${NC}"
        fi
        
        # Remove backup
        rm "$compose_file.backup"
    else
        echo -e "${RED}✗ Compose file not found: $compose_file${NC}"
    fi
}

# Function to update service-specific compose files
update_service_compose_files() {
    local registry="$1"
    local tag="$2"
    
    declare -A services=(
        ["passwordmanager"]="services/frontend/passwordmanager/docker-compose.yml"
        ["syncservice"]="services/frontend/syncservice/docker-compose.yml"
        ["website"]="services/frontend/website/docker-compose.yml"
        ["pwdmanager-backend"]="services/backend/pwdmanager/docker-compose.yml"
        ["email-backend"]="services/backend/email/docker-compose.yml"
        ["nas"]="services/backend/nas/docker-compose.yml"
    )
    
    for service_name in "${!services[@]}"; do
        local compose_file="$(dirname "$0")/../${services[$service_name]}"
        local new_image="$registry/$service_name:$tag"
        
        update_compose_image "$compose_file" "$service_name" "$new_image"
    done
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Update Compose Images ===${NC}"
echo -e "${CYAN}Registry: $REGISTRY${NC}"
echo -e "${CYAN}Tag: $TAG${NC}"

# Update service-specific compose files
update_service_compose_files "$REGISTRY" "$TAG"

echo -e "${GREEN}=== Update Complete ===${NC}"
echo -e "${CYAN}All docker-compose files have been updated to use built images.${NC}" 