#!/bin/bash

# UnCloud - Docker Image Build Script
# This script builds all Docker images for the UnCloud infrastructure

set -e

# Default values
REGISTRY=${1:-"uncloud"}
TAG=${2:-"latest"}
PUSH=${3:-"false"}
NO_CACHE=${4:-"false"}
PLATFORM=${5:-"linux/amd64"}

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

# Function to build Docker image
build_docker_image() {
    local service_name="$1"
    local dockerfile_path="$2"
    local context_path="$3"
    local registry="$4"
    local tag="$5"
    local no_cache="$6"
    
    local image_name="$registry/$service_name"
    local full_tag="$image_name:$tag"
    
    echo -e "${GREEN}Building $service_name...${NC}"
    echo -e "${CYAN}  Image: $full_tag${NC}"
    echo -e "${CYAN}  Dockerfile: $dockerfile_path${NC}"
    echo -e "${CYAN}  Context: $context_path${NC}"
    
    build_args=("build" "--platform" "$PLATFORM" "--file" "$dockerfile_path" "--tag" "$full_tag")
    
    if [ "$no_cache" = "true" ]; then
        build_args+=("--no-cache")
    fi
    
    build_args+=("$context_path")
    
    if docker "${build_args[@]}"; then
        echo -e "${GREEN}✓ Successfully built $full_tag${NC}"
        
        if [ "$PUSH" = "true" ]; then
            echo -e "${YELLOW}Pushing $full_tag...${NC}"
            if docker push "$full_tag"; then
                echo -e "${GREEN}✓ Successfully pushed $full_tag${NC}"
            else
                echo -e "${RED}✗ Failed to push $full_tag${NC}"
            fi
        fi
        return 0
    else
        echo -e "${RED}✗ Failed to build $full_tag${NC}"
        return 1
    fi
}

# Function to check if Docker is running
check_docker_running() {
    if ! docker version >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Docker Image Build ===${NC}"
echo -e "${CYAN}Registry: $REGISTRY${NC}"
echo -e "${CYAN}Tag: $TAG${NC}"
echo -e "${CYAN}Platform: $PLATFORM${NC}"
echo -e "${CYAN}Push: $PUSH${NC}"
echo -e "${CYAN}No Cache: $NO_CACHE${NC}"

# Check if Docker is running
check_docker_running

# Define services to build
declare -A services=(
    ["passwordmanager"]="build/dockerfiles/passwordmanager/Dockerfile:services/frontend/passwordmanager"
    ["syncservice"]="build/dockerfiles/syncservice/Dockerfile:services/frontend/syncservice"
    ["website"]="build/dockerfiles/website/Dockerfile:services/frontend/website"
    ["pwdmanager-backend"]="build/dockerfiles/pwdmanager-backend/Dockerfile:services/backend/pwdmanager"
    ["email-backend"]="build/dockerfiles/email-backend/Dockerfile:services/backend/email"
    ["nas"]="build/dockerfiles/nas/Dockerfile:services/backend/nas"
)

# Build all services
success_count=0
total_count=${#services[@]}

for service_name in "${!services[@]}"; do
    IFS=':' read -r dockerfile_path context_path <<< "${services[$service_name]}"
    
    full_dockerfile_path="$(dirname "$0")/../$dockerfile_path"
    full_context_path="$(dirname "$0")/../$context_path"
    
    if [ -f "$full_dockerfile_path" ]; then
        if build_docker_image "$service_name" "$full_dockerfile_path" "$full_context_path" "$REGISTRY" "$TAG" "$NO_CACHE"; then
            ((success_count++))
        fi
    else
        echo -e "${RED}✗ Dockerfile not found: $full_dockerfile_path${NC}"
    fi
done

# Summary
echo -e "${MAGENTA}=== Build Summary ===${NC}"
if [ $success_count -eq $total_count ]; then
    echo -e "${GREEN}Successfully built: $success_count/$total_count images${NC}"
    echo -e "${GREEN}✓ All images built successfully!${NC}"
    exit 0
else
    echo -e "${YELLOW}Successfully built: $success_count/$total_count images${NC}"
    echo -e "${RED}✗ Some images failed to build${NC}"
    exit 1
fi 