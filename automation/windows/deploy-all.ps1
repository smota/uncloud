# UnCloud - Full Deployment Script (Single Host)
# This script deploys all services on a single host

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

# Function to deploy services
function Deploy-Services {
    param(
        [string]$ComposeFile,
        [string]$StackName
    )
    
    Write-Host "Deploying stack: $StackName" -ForegroundColor Green
    
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
        Write-Host "Stack $StackName deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to deploy stack $StackName" -ForegroundColor Red
        exit 1
    }
}

# Function to wait for services to be ready
function Wait-ServicesReady {
    param(
        [string]$StackName,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
    
    $startTime = Get-Date
    $timeout = $startTime.AddSeconds($TimeoutSeconds)
    
    while ((Get-Date) -lt $timeout) {
        $services = docker stack services $StackName --format "{{.Name}} {{.Replicas}}" 2>$null
        
        $allReady = $true
        foreach ($service in $services) {
            if ($service -match '(\S+)\s+(\d+)/(\d+)') {
                $serviceName = $matches[1]
                $ready = [int]$matches[2]
                $total = [int]$matches[3]
                
                if ($ready -lt $total) {
                    $allReady = $false
                    Write-Host "Service $serviceName: $ready/$total ready" -ForegroundColor Yellow
                }
            }
        }
        
        if ($allReady) {
            Write-Host "All services are ready!" -ForegroundColor Green
            return
        }
        
        Start-Sleep -Seconds 10
    }
    
    Write-Host "WARNING: Some services may not be fully ready" -ForegroundColor Yellow
}

# Function to show service status
function Show-ServiceStatus {
    param(
        [string]$StackName
    )
    
    Write-Host "=== Service Status ===" -ForegroundColor Magenta
    docker stack services $StackName
    Write-Host ""
    
    Write-Host "=== Service Logs (last 10 lines) ===" -ForegroundColor Magenta
    $services = docker stack services $StackName --format "{{.Name}}" 2>$null
    foreach ($service in $services) {
        Write-Host "--- $service ---" -ForegroundColor Cyan
        docker service logs --tail 10 $service 2>$null
        Write-Host ""
    }
}

# Main execution
Write-Host "=== UnCloud Full Deployment ===" -ForegroundColor Magenta
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Mode: Single Host Deployment" -ForegroundColor Cyan

# Check if Docker Swarm is active
if (-not (Test-SwarmActive)) {
    Write-Host "ERROR: Docker Swarm is not active. Run init-swarm.ps1 first." -ForegroundColor Red
    exit 1
}

# Get the project root directory
$ProjectRoot = Join-Path $PSScriptRoot "..\.."
$ComposeFile = Join-Path $ProjectRoot "docker-compose.yml"

# Check if compose file exists
if (-not (Test-Path $ComposeFile)) {
    Write-Host "ERROR: docker-compose.yml not found at $ComposeFile" -ForegroundColor Red
    exit 1
}

# Deploy all services
$StackName = $env:PROJECT_NAME
if (-not $StackName) {
    $StackName = "uncloud"
}

Write-Host "Deploying stack: $StackName" -ForegroundColor Green
Deploy-Services -ComposeFile $ComposeFile -StackName $StackName

# Wait for services to be ready
Wait-ServicesReady -StackName $StackName

# Show service status
Show-ServiceStatus -StackName $StackName

Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Access your services at:" -ForegroundColor Cyan
Write-Host "  - Website: https://$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Password Manager: https://$($env:SUBDOMAIN_PASSWORDMANAGER).$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Sync Service: https://$($env:SUBDOMAIN_SYNC).$($env:DOMAIN_NAME)" -ForegroundColor White
Write-Host "  - Traefik Dashboard: https://traefik.$($env:DOMAIN_NAME)" -ForegroundColor White 