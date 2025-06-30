#!/bin/bash

# UnCloud - Build and Deploy Script
# This script builds all Docker images and deploys the infrastructure

set -e

# Default values
REGISTRY=${1:-"uncloud"}
TAG=${2:-"latest"}
PUSH=${3:-"false"}
NO_CACHE=${4:-"false"}
SKIP_BUILD=${5:-"false"}
SKIP_DEPLOY=${6:-"false"}
PLATFORM=${7:-"linux/amd64"}
DEPLOYMENT_TYPE=${8:-"all"} # all, frontend, backend

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

# Function to check if Docker is running
check_docker_running() {
    if ! docker version >/dev/null 2>&1; then
        echo -e "${RED}ERROR: Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
}

# Function to check if Docker Swarm is active
check_swarm_active() {
    swarm_state=$(docker info --format "{{.Swarm.LocalNodeState}}" 2>/dev/null || echo "inactive")
    if [ "$swarm_state" != "active" ]; then
        echo -e "${RED}ERROR: Docker Swarm is not active. Run init-swarm.sh first.${NC}"
        exit 1
    fi
}

# Function to build images
build_images() {
    echo -e "${MAGENTA}=== Building Docker Images ===${NC}"
    
    build_script="$(dirname "$0")/build-images.sh"
    build_args=("$REGISTRY" "$TAG" "$PUSH" "$NO_CACHE" "$PLATFORM")
    
    if "$build_script" "${build_args[@]}"; then
        echo -e "${GREEN}✓ Images built successfully${NC}"
    else
        echo -e "${RED}✗ Image build failed${NC}"
        exit 1
    fi
}

# Function to update compose files
update_compose_files() {
    echo -e "${MAGENTA}=== Updating Compose Files ===${NC}"
    
    update_script="$(dirname "$0")/update-compose-images.sh"
    if "$update_script" "$REGISTRY" "$TAG"; then
        echo -e "${GREEN}✓ Compose files updated successfully${NC}"
    else
        echo -e "${RED}✗ Compose file update failed${NC}"
        exit 1
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo -e "${MAGENTA}=== Deploying Infrastructure ===${NC}"
    
    deploy_script="$(dirname "$0")/../automation/linux/deploy-$DEPLOYMENT_TYPE.sh"
    
    if [ -f "$deploy_script" ]; then
        if "$deploy_script"; then
            echo -e "${GREEN}✓ Deployment completed successfully${NC}"
        else
            echo -e "${RED}✗ Deployment failed${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ Deployment script not found: $deploy_script${NC}"
        exit 1
    fi
}

# Function to show deployment status
show_deployment_status() {
    echo -e "${MAGENTA}=== Deployment Status ===${NC}"
    
    stack_name="${PROJECT_NAME:-uncloud}"
    if [ "$DEPLOYMENT_TYPE" != "all" ]; then
        stack_name="${stack_name}_${DEPLOYMENT_TYPE}"
    fi
    
    echo -e "${CYAN}Checking stack: $stack_name${NC}"
    docker stack services "$stack_name"
    
    echo -e "${CYAN}Service logs (last 5 lines):${NC}"
    services=$(docker stack services "$stack_name" --format "{{.Name}}" 2>/dev/null || true)
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            echo -e "${YELLOW}--- $service ---${NC}"
            docker service logs --tail 5 "$service" 2>/dev/null || true
            echo
        fi
    done <<< "$services"
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Build and Deploy ===${NC}"
echo -e "${CYAN}Registry: $REGISTRY${NC}"
echo -e "${CYAN}Tag: $TAG${NC}"
echo -e "${CYAN}Platform: $PLATFORM${NC}"
echo -e "${CYAN}Push: $PUSH${NC}"
echo -e "${CYAN}No Cache: $NO_CACHE${NC}"
echo -e "${CYAN}Skip Build: $SKIP_BUILD${NC}"
echo -e "${CYAN}Skip Deploy: $SKIP_DEPLOY${NC}"
echo -e "${CYAN}Deployment Type: $DEPLOYMENT_TYPE${NC}"

# Check prerequisites
check_docker_running

if [ "$SKIP_DEPLOY" != "true" ]; then
    check_swarm_active
fi

# Build images (if not skipped)
if [ "$SKIP_BUILD" != "true" ]; then
    build_images
    update_compose_files
else
    echo -e "${YELLOW}Skipping image build as requested${NC}"
fi

# Deploy infrastructure (if not skipped)
if [ "$SKIP_DEPLOY" != "true" ]; then
    deploy_infrastructure
    show_deployment_status
else
    echo -e "${YELLOW}Skipping deployment as requested${NC}"
fi

echo -e "${GREEN}=== Build and Deploy Complete ===${NC}"

if [ "$SKIP_DEPLOY" != "true" ]; then
    echo -e "${CYAN}Access your services at:${NC}"
    echo -e "${NC}  - Website: https://$DOMAIN_NAME${NC}"
    echo -e "${NC}  - Password Manager: https://$SUBDOMAIN_PASSWORDMANAGER.$DOMAIN_NAME${NC}"
    echo -e "${NC}  - Sync Service: https://$SUBDOMAIN_SYNC.$DOMAIN_NAME${NC}"
    echo -e "${NC}  - Traefik Dashboard: https://traefik.$DOMAIN_NAME${NC}"
fi 