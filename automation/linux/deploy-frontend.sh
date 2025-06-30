#!/bin/bash

# UnCloud - Frontend Deployment Script
# This script deploys only frontend services for distributed deployment

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

# Function to create frontend-only compose file
create_frontend_compose_file() {
    PROJECT_ROOT="$(dirname "$0")/../.."
    ORIGINAL_COMPOSE="$PROJECT_ROOT/docker-compose.yml"
    FRONTEND_COMPOSE="$PROJECT_ROOT/docker-compose-frontend.yml"
    
    # Create frontend-only compose file
    cat > "$FRONTEND_COMPOSE" << 'EOF'
version: '3.8'

services:
  # Frontend Services (External Access)
  passwordmanager:
    extends:
      file: ./services/frontend/passwordmanager/docker-compose.yml
      service: passwordmanager
  
  syncservice:
    extends:
      file: ./services/frontend/syncservice/docker-compose.yml
      service: syncservice
  
  website:
    extends:
      file: ./services/frontend/website/docker-compose.yml
      service: website
  
  # Infrastructure Services
  traefik:
    extends:
      file: ./services/infrastructure/traefik/docker-compose.yml
      service: traefik
  
  dns:
    extends:
      file: ./services/infrastructure/dns/docker-compose.yml
      service: dns
  
  loadbalancer:
    extends:
      file: ./services/infrastructure/loadbalancer/docker-compose.yml
      service: loadbalancer

networks:
  frontend:
    external: true
  backend:
    external: true
  infrastructure:
    external: true

volumes:
  shared_data:
    external: true
  secrets:
    external: true
EOF
    
    echo "$FRONTEND_COMPOSE"
}

# Function to deploy services
deploy_services() {
    local compose_file="$1"
    local stack_name="$2"
    
    echo -e "${GREEN}Deploying frontend stack: $stack_name${NC}"
    
    deploy_args=("stack" "deploy" "--compose-file" "$compose_file" "--with-registry-auth")
    
    if [ "$UPDATE" = "true" ]; then
        deploy_args+=("--prune")
    fi
    
    deploy_args+=("$stack_name")
    
    if docker "${deploy_args[@]}"; then
        echo -e "${GREEN}Frontend stack $stack_name deployed successfully${NC}"
    else
        echo -e "${RED}ERROR: Failed to deploy frontend stack $stack_name${NC}"
        exit 1
    fi
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Frontend Deployment ===${NC}"
echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}Mode: Frontend Services Only${NC}"

# Check if Docker Swarm is active
check_swarm_active

# Create frontend-only compose file
COMPOSE_FILE=$(create_frontend_compose_file)

# Deploy frontend services
STACK_NAME="${PROJECT_NAME:-uncloud}_frontend"

echo -e "${GREEN}Deploying frontend stack: $STACK_NAME${NC}"
deploy_services "$COMPOSE_FILE" "$STACK_NAME"

echo -e "${GREEN}=== Frontend Deployment Complete ===${NC}"
echo -e "${CYAN}Frontend services deployed. Backend services must be deployed separately.${NC}"
echo -e "${CYAN}Access your frontend services at:${NC}"
echo -e "${NC}  - Website: https://$DOMAIN_NAME${NC}"
echo -e "${NC}  - Password Manager: https://$SUBDOMAIN_PASSWORDMANAGER.$DOMAIN_NAME${NC}"
echo -e "${NC}  - Sync Service: https://$SUBDOMAIN_SYNC.$DOMAIN_NAME${NC}"
echo -e "${NC}  - Traefik Dashboard: https://traefik.$DOMAIN_NAME${NC}" 