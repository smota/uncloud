# UnCloud - Build and Deploy Script
# This script builds all Docker images and deploys the infrastructure

param(
    [string]$Registry = "uncloud",
    [string]$Tag = "latest",
    [switch]$Push = $false,
    [switch]$NoCache = $false,
    [switch]$SkipBuild = $false,
    [switch]$SkipDeploy = $false,
    [string]$Platform = "linux/amd64",
    [string]$DeploymentType = "all" # all, frontend, backend
)

# Load configuration
$ConfigPath = Join-Path $PSScriptRoot "..\config\common.env"
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

# Function to check if Docker Swarm is active
function Test-SwarmActive {
    $swarmInfo = docker info --format "{{.Swarm.LocalNodeState}}" 2>$null
    return $swarmInfo -eq "active"
}

# Function to build images
function Build-Images {
    Write-Host "=== Building Docker Images ===" -ForegroundColor Magenta
    
    $buildScript = Join-Path $PSScriptRoot "build-images.ps1"
    $buildArgs = @(
        "-Registry", $Registry,
        "-Tag", $Tag,
        "-Platform", $Platform
    )
    
    if ($Push) {
        $buildArgs += "-Push"
    }
    
    if ($NoCache) {
        $buildArgs += "-NoCache"
    }
    
    & $buildScript @buildArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Image build failed" -ForegroundColor Red
        exit 1
    }
}

# Function to update compose files
function Update-ComposeFiles {
    Write-Host "=== Updating Compose Files ===" -ForegroundColor Magenta
    
    $updateScript = Join-Path $PSScriptRoot "update-compose-images.ps1"
    & $updateScript -Registry $Registry -Tag $Tag
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Compose file update failed" -ForegroundColor Red
        exit 1
    }
}

# Function to deploy infrastructure
function Deploy-Infrastructure {
    Write-Host "=== Deploying Infrastructure ===" -ForegroundColor Magenta
    
    $deployScript = Join-Path $PSScriptRoot "..\automation\windows\deploy-$DeploymentType.ps1"
    
    if (Test-Path $deployScript) {
        & $deployScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Deployment failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✗ Deployment script not found: $deployScript" -ForegroundColor Red
        exit 1
    }
}

# Function to show deployment status
function Show-DeploymentStatus {
    Write-Host "=== Deployment Status ===" -ForegroundColor Magenta
    
    $StackName = $env:PROJECT_NAME
    if (-not $StackName) {
        $StackName = "uncloud"
    }
    
    if ($DeploymentType -ne "all") {
        $StackName = "$StackName`_$DeploymentType"
    }
    
    Write-Host "Checking stack: $StackName" -ForegroundColor Cyan
    docker stack services $StackName
    
    Write-Host "`nService logs (last 5 lines):" -ForegroundColor Cyan
    $services = docker stack services $StackName --format "{{.Name}}" 2>$null
    foreach ($service in $services) {
        Write-Host "--- $service ---" -ForegroundColor Yellow
        docker service logs --tail 5 $service 2>$null
        Write-Host ""
    }
}

# Main execution
Write-Host "=== UnCloud Build and Deploy ===" -ForegroundColor Magenta
Write-Host "Registry: $Registry" -ForegroundColor Cyan
Write-Host "Tag: $Tag" -ForegroundColor Cyan
Write-Host "Platform: $Platform" -ForegroundColor Cyan
Write-Host "Push: $Push" -ForegroundColor Cyan
Write-Host "No Cache: $NoCache" -ForegroundColor Cyan
Write-Host "Skip Build: $SkipBuild" -ForegroundColor Cyan
Write-Host "Skip Deploy: $SkipDeploy" -ForegroundColor Cyan
Write-Host "Deployment Type: $DeploymentType" -ForegroundColor Cyan

# Check prerequisites
if (-not (Test-DockerRunning)) {
    Write-Host "ERROR: Docker is not running. Please start Docker and try again." -ForegroundColor Red
    exit 1
}

if (-not $SkipDeploy -and -not (Test-SwarmActive)) {
    Write-Host "ERROR: Docker Swarm is not active. Run init-swarm.ps1 first." -ForegroundColor Red
    exit 1
}

# Build images (if not skipped)
if (-not $SkipBuild) {
    Build-Images
    Update-ComposeFiles
} else {
    Write-Host "Skipping image build as requested" -ForegroundColor Yellow
}

# Deploy infrastructure (if not skipped)
if (-not $SkipDeploy) {
    Deploy-Infrastructure
    Show-DeploymentStatus
} else {
    Write-Host "Skipping deployment as requested" -ForegroundColor Yellow
}

Write-Host "=== Build and Deploy Complete ===" -ForegroundColor Green

if (-not $SkipDeploy) {
    Write-Host "Access your services at:" -ForegroundColor Cyan
    Write-Host "  - Website: https://$($env:DOMAIN_NAME)" -ForegroundColor White
    Write-Host "  - Password Manager: https://$($env:SUBDOMAIN_PASSWORDMANAGER).$($env:DOMAIN_NAME)" -ForegroundColor White
    Write-Host "  - Sync Service: https://$($env:SUBDOMAIN_SYNC).$($env:DOMAIN_NAME)" -ForegroundColor White
    Write-Host "  - Traefik Dashboard: https://traefik.$($env:DOMAIN_NAME)" -ForegroundColor White
} 