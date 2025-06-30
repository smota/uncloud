#!/bin/bash

# UnCloud - Backend Deployment Script
# This script deploys only backend services for distributed deployment

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

# Function to create backend-only compose file
create_backend_compose_file() {
    PROJECT_ROOT="$(dirname "$0")/../.."
    BACKEND_COMPOSE="$PROJECT_ROOT/docker-compose-backend.yml"
    
    # Create backend-only compose file
    cat > "$BACKEND_COMPOSE" << 'EOF'
version: '3.8'

services:
  # Backend Services (Internal Only)
  email-backend:
    extends:
      file: ./services/backend/email/docker-compose.yml
      service: email-backend
  
  database:
    extends:
      file: ./services/backend/database/docker-compose.yml
      service: database
  
  pwdmanager-backend:
    extends:
      file: ./services/backend/pwdmanager/docker-compose.yml
      service: pwdmanager-backend
  
  nas:
    extends:
      file: ./services/backend/nas/docker-compose.yml
      service: nas

networks:
  backend:
    external: true

volumes:
  shared_data:
    external: true
  secrets:
    external: true
EOF
    
    echo "$BACKEND_COMPOSE"
}

# Function to deploy services
deploy_services() {
    local compose_file="$1"
    local stack_name="$2"
    
    echo -e "${GREEN}Deploying backend stack: $stack_name${NC}"
    
    deploy_args=("stack" "deploy" "--compose-file" "$compose_file" "--with-registry-auth")
    
    if [ "$UPDATE" = "true" ]; then
        deploy_args+=("--prune")
    fi
    
    deploy_args+=("$stack_name")
    
    if docker "${deploy_args[@]}"; then
        echo -e "${GREEN}Backend stack $stack_name deployed successfully${NC}"
    else
        echo -e "${RED}ERROR: Failed to deploy backend stack $stack_name${NC}"
        exit 1
    fi
}

# Function to wait for database to be ready
wait_database_ready() {
    echo -e "${YELLOW}Waiting for database to be ready...${NC}"
    
    start_time=$(date +%s)
    timeout=$((start_time + 120))
    
    while [ $(date +%s) -lt $timeout ]; do
        db_service=$(docker service ls --filter "name=database" --format "{{.Replicas}}" 2>/dev/null || true)
        if [[ $db_service =~ ([0-9]+)/([0-9]+) ]]; then
            ready="${BASH_REMATCH[1]}"
            total="${BASH_REMATCH[2]}"
            if [ "$ready" -eq "$total" ]; then
                echo -e "${GREEN}Database is ready!${NC}"
                return
            fi
        fi
        sleep 5
    done
    
    echo -e "${YELLOW}WARNING: Database may not be fully ready${NC}"
}

# Main execution
echo -e "${MAGENTA}=== UnCloud Backend Deployment ===${NC}"
echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}Mode: Backend Services Only${NC}"

# Check if Docker Swarm is active
check_swarm_active

# Create backend-only compose file
COMPOSE_FILE=$(create_backend_compose_file)

# Deploy backend services
STACK_NAME="${PROJECT_NAME:-uncloud}_backend"

echo -e "${GREEN}Deploying backend stack: $STACK_NAME${NC}"
deploy_services "$COMPOSE_FILE" "$STACK_NAME"

# Wait for database to be ready
wait_database_ready

echo -e "${GREEN}=== Backend Deployment Complete ===${NC}"
echo -e "${CYAN}Backend services deployed. Frontend services can now connect to backend services.${NC}"
echo -e "${YELLOW}Backend services are internal-only and not accessible from external networks.${NC}" 