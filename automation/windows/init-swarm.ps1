# UnCloud - Docker Swarm Initialization Script
# This script initializes the Docker Swarm infrastructure

param(
    [string]$Environment = "production",
    [switch]$Force = $false
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

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker version | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Function to create external networks
function New-ExternalNetworks {
    Write-Host "Creating external networks..." -ForegroundColor Green
    
    $networks = @(
        $env:FRONTEND_NETWORK,
        $env:BACKEND_NETWORK,
        $env:INFRASTRUCTURE_NETWORK
    )
    
    foreach ($network in $networks) {
        if (-not (docker network ls --filter "name=$network" --format "{{.Name}}" | Select-String $network)) {
            Write-Host "Creating network: $network" -ForegroundColor Yellow
            docker network create --driver overlay --attachable $network
        } else {
            Write-Host "Network $network already exists" -ForegroundColor Cyan
        }
    }
}

# Function to create external volumes
function New-ExternalVolumes {
    Write-Host "Creating external volumes..." -ForegroundColor Green
    
    $volumes = @(
        $env:SHARED_DATA_VOLUME,
        $env:SECRETS_VOLUME,
        "database_data",
        "traefik_data",
        "dns_data",
        "loadbalancer_data",
        "sync_data",
        "website_data",
        "email_data",
        "pwdmanager_data",
        "nas_data",
        "backup_data"
    )
    
    foreach ($volume in $volumes) {
        if (-not (docker volume ls --filter "name=$volume" --format "{{.Name}}" | Select-String $volume)) {
            Write-Host "Creating volume: $volume" -ForegroundColor Yellow
            docker volume create $volume
        } else {
            Write-Host "Volume $volume already exists" -ForegroundColor Cyan
        }
    }
}

# Function to initialize Docker Swarm
function Initialize-DockerSwarm {
    Write-Host "Initializing Docker Swarm..." -ForegroundColor Green
    
    $swarmInfo = docker info --format "{{.Swarm.LocalNodeState}}" 2>$null
    if ($swarmInfo -eq "inactive") {
        Write-Host "Initializing new Swarm..." -ForegroundColor Yellow
        docker swarm init
    } elseif ($swarmInfo -eq "active") {
        Write-Host "Swarm is already active" -ForegroundColor Cyan
    } else {
        Write-Host "Swarm status: $swarmInfo" -ForegroundColor Yellow
    }
}

# Function to validate secrets
function Test-SecretsConfiguration {
    Write-Host "Validating secrets configuration..." -ForegroundColor Green
    
    $secretsPath = Join-Path $PSScriptRoot "..\..\secrets\.env"
    if (-not (Test-Path $secretsPath)) {
        Write-Host "ERROR: Secrets file not found at $secretsPath" -ForegroundColor Red
        Write-Host "Please copy secrets/env.template to secrets/.env and configure your secrets" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Secrets file found and validated" -ForegroundColor Green
}

# Main execution
Write-Host "=== UnCloud Docker Swarm Initialization ===" -ForegroundColor Magenta
Write-Host "Environment: $Environment" -ForegroundColor Cyan

# Check if Docker is running
if (-not (Test-DockerRunning)) {
    Write-Host "ERROR: Docker is not running. Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

# Validate secrets
Test-SecretsConfiguration

# Initialize Swarm
Initialize-DockerSwarm

# Create networks
New-ExternalNetworks

# Create volumes
New-ExternalVolumes

Write-Host "=== Initialization Complete ===" -ForegroundColor Green
Write-Host "You can now run the deployment scripts:" -ForegroundColor Cyan
Write-Host "  - deploy-all.ps1 (for single host deployment)" -ForegroundColor White
Write-Host "  - deploy-frontend.ps1 (for frontend-only deployment)" -ForegroundColor White
Write-Host "  - deploy-backend.ps1 (for backend-only deployment)" -ForegroundColor White 