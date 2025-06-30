#!/bin/bash

# UnCloud - Full Deployment Script (Single Host)
# This script deploys all services on a single host

set -e

# Default values
ENVIRONMENT=${1:-"production"}
FORCE=${2:-"false"}
UPDATE=${3:-"false"}

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

# Function to check if Docker Swarm is active
check_swarm_active() {
    swarm_state=$(docker info --format "{{.Swarm.LocalNodeState}}" 2>/dev/null || echo "inactive")
    if [ "$swarm_state" != "active" ]; then
        echo -e "${RED}ERROR: Docker Swarm is not active. Run init-swarm.sh first.${NC}"
        exit 1
    fi
}

# Function to deploy services
deploy_services() {
    local compose_file="$1"
    local stack_name="$2"
    
    echo -e "${GREEN}Deploying stack: $stack_name${NC}"
    
    deploy_args=("stack" "deploy" "--compose-file" "$compose_file" "--with-registry-auth")
    
    if [ "$UPDATE" = "true" ]; then
        deploy_args+=("--prune")
    fi
    
    deploy_args+=("$stack_name")
    
    if docker "${deploy_args[@]}"; then
        echo -e "${GREEN}Stack $stack_name deployed successfully${NC}"
    else
        echo -e "${RED}ERROR: Failed to deploy stack $stack_name${NC}"
        exit 1
    fi
}

# Function to wait for services to be ready
wait_services_ready() {
    local stack_name="$1"
    local timeout_seconds="${2:-300}"
    
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    
    start_time=$(date +%s)
    timeout=$((start_time + timeout_seconds))
    
    while [ $(date +%s) -lt $timeout ]; do
        services=$(docker stack services "$stack_name" --format "{{.Name}} {{.Replicas}}" 2>/dev/null || true)
        
        all_ready=true
        while IFS= read -r service; do
            if [[ $service =~ ([^[:space:]]+)[[:space:]]+([0-9]+)/([0-9]+) ]]; then
                service_name="${BASH_REMATCH[1]}"
                ready="${BASH_REMATCH[2]}"
                total="${BASH_REMATCH[3]}"
                
                if [ "$ready" -lt "$total" ]; then
                    all_ready=false
                    echo -e "${YELLOW}Service $service_name: $ready/$total ready${NC}"
                fi
            fi
        done <<< "$services"
        
        if [ "$all_ready" = true ]; then
            echo -e "${GREEN}All services are ready!${NC}"
            return
        fi
        
        sleep 10
    done
    
    echo -e "${YELLOW}WARNING: Some services may not be fully ready${NC}"
}

# Function to show service status
show_service_status() {
    local stack_name="$1"
    
    echo -e "${MAGENTA}=== Service Status ===${NC}"
    docker stack services "$stack_name"
    echo
    
    echo -e "${MAGENTA}=== Service Logs (last 10 lines) ===${NC}"
    services=$(docker stack services "$stack_name" --format "{{.Name}}" 2>/dev/null || true)
    while IFS= read -r service; do
        if [ -n "$service" ]; then
            echo -e "${CYAN}--- $service ---${NC}"
            docker service logs --tail 10 "$service" 2>/dev/null || true
            echo
        fi
    done <<< "$services"
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Full Deployment ===${NC}"
echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}Mode: Single Host Deployment${NC}"

# Check if Docker Swarm is active
check_swarm_active

# Get the project root directory
PROJECT_ROOT="$(dirname "$0")/../.."
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}ERROR: docker-compose.yml not found at $COMPOSE_FILE${NC}"
    exit 1
fi

# Deploy all services
STACK_NAME="${PROJECT_NAME:-uncloud}"

echo -e "${GREEN}Deploying stack: $STACK_NAME${NC}"
deploy_services "$COMPOSE_FILE" "$STACK_NAME"

# Wait for services to be ready
wait_services_ready "$STACK_NAME"

# Show service status
show_service_status "$STACK_NAME"

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${CYAN}Access your services at:${NC}"
echo -e "${NC}  - Website: https://$DOMAIN_NAME${NC}"
echo -e "${NC}  - Password Manager: https://$SUBDOMAIN_PASSWORDMANAGER.$DOMAIN_NAME${NC}"
echo -e "${NC}  - Sync Service: https://$SUBDOMAIN_SYNC.$DOMAIN_NAME${NC}"
echo -e "${NC}  - Traefik Dashboard: https://traefik.$DOMAIN_NAME${NC}" 