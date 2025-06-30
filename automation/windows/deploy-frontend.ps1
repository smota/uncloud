# UnCloud - Frontend Deployment Script
# This script deploys only frontend services for distributed deployment

param(
    [string]$Environment = "production",
    [switch]$Force = $false,
    [switch]$Update = $false
)

# Load configuration
$ConfigPath = Join-Path $PSScriptRoot "..\..\config\common.env"
if (Test-Path $ConfigPath) {
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
}

# Function to check if Docker Swarm is active
function Test-SwarmActive {
    $swarmInfo = docker info --format "{{.Swarm.LocalNodeState}}" 2>$null
    return $swarmInfo -eq "active"
}

# Function to create frontend-only compose file
function New-FrontendComposeFile {
    $ProjectRoot = Join-Path $PSScriptRoot "..\.."
    $OriginalCompose = Join-Path $ProjectRoot "docker-compose.yml"
    $FrontendCompose = Join-Path $ProjectRoot "docker-compose-frontend.yml"
    
    # Read the original compose file
    $content = Get-Content $OriginalCompose -Raw
    
    # Extract only frontend and infrastructure services
    $frontendServices = @"
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
"@
    
    # Write the frontend-only compose file
    $frontendServices | Out-File -FilePath $FrontendCompose -Encoding UTF8
    
    return $FrontendCompose
}

# Function to deploy services
function Deploy-Services {
    param(
        [string]$ComposeFile,
        [string]$StackName
    )
    
    Write-Host "Deploying frontend stack: $StackName" -ForegroundColor Green
    
    $deployArgs = @(
        "stack", "deploy",
        "--compose-file", $ComposeFile,
        "--with-registry-auth"
    )
    
    if ($Update) {
        $deployArgs += "--prune"
    }
    
    $deployArgs += $StackName
    
    docker $deployArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Frontend stack $StackName deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to deploy frontend stack $StackName" -ForegroundColor Red
        exit 1
    }
}

# Main execution
Write-Host "=== UnCloud Frontend Deployment ===" -ForegroundColor Magenta
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Mode: Frontend Services Only" -ForegroundColor Cyan

# Check if Docker Swarm is active
if (-not (Test-SwarmActive)) {
    Write-Host "ERROR: Docker Swarm is not active. Run init-swarm.ps1 first." -ForegroundColor Red
    exit 1
}

# Create frontend-only compose file
$ComposeFile = New-FrontendComposeFile

# Deploy frontend services
$StackName = "$($env:PROJECT_NAME)_frontend"
if (-not $env:PROJECT_NAME) {
    $StackName = "uncloud_frontend"
}

Write-Host "Deploying frontend stack: $StackName" -ForegroundColor Green
Deploy-Services -ComposeFile $ComposeFile -StackName $StackName

Write-Host "=== Frontend Deployment Complete ===" -ForegroundColor Green
Write-Host "Frontend services deployed. Backend services must be deployed separately." -ForegroundColor Cyan
Write-Host "Access your frontend services at:" -ForegroundColor Cyan
Write-Host "  - Website: https://$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Password Manager: https://$($env:SUBDOMAIN_PASSWORDMANAGER).$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Sync Service: https://$($env:SUBDOMAIN_SYNC).$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Traefik Dashboard: https://traefik.$($env:DOMAIN_NAME)" -ForegroundColor White 