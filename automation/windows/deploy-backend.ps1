# UnCloud - Backend Deployment Script
# This script deploys only backend services for distributed deployment

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

# Function to create backend-only compose file
function New-BackendComposeFile {
    $ProjectRoot = Join-Path $PSScriptRoot "..\.."
    $OriginalCompose = Join-Path $ProjectRoot "docker-compose.yml"
    $BackendCompose = Join-Path $ProjectRoot "docker-compose-backend.yml"
    
    # Extract only backend services
    $backendServices = @"
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
"@
    
    # Write the backend-only compose file
    $backendServices | Out-File -FilePath $BackendCompose -Encoding UTF8
    
    return $BackendCompose
}

# Function to deploy services
function Deploy-Services {
    param(
        [string]$ComposeFile,
        [string]$StackName
    )
    
    Write-Host "Deploying backend stack: $StackName" -ForegroundColor Green
    
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
        Write-Host "Backend stack $StackName deployed successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to deploy backend stack $StackName" -ForegroundColor Red
        exit 1
    }
}

# Function to wait for database to be ready
function Wait-DatabaseReady {
    Write-Host "Waiting for database to be ready..." -ForegroundColor Yellow
    
    $startTime = Get-Date
    $timeout = $startTime.AddSeconds(120)
    
    while ((Get-Date) -lt $timeout) {
        try {
            $dbService = docker service ls --filter "name=database" --format "{{.Replicas}}" 2>$null
            if ($dbService -match '(\d+)/(\d+)') {
                $ready = [int]$matches[1]
                $total = [int]$matches[2]
                if ($ready -eq $total) {
                    Write-Host "Database is ready!" -ForegroundColor Green
                    return
                }
            }
        }
        catch {
            # Continue waiting
        }
        
        Start-Sleep -Seconds 5
    }
    
    Write-Host "WARNING: Database may not be fully ready" -ForegroundColor Yellow
}

# Main execution
Write-Host "=== UnCloud Backend Deployment ===" -ForegroundColor Magenta
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Mode: Backend Services Only" -ForegroundColor Cyan

# Check if Docker Swarm is active
if (-not (Test-SwarmActive)) {
    Write-Host "ERROR: Docker Swarm is not active. Run init-swarm.ps1 first." -ForegroundColor Red
    exit 1
}

# Create backend-only compose file
$ComposeFile = New-BackendComposeFile

# Deploy backend services
$StackName = "$($env:PROJECT_NAME)_backend"
if (-not $env:PROJECT_NAME) {
    $StackName = "uncloud_backend"
}

Write-Host "Deploying backend stack: $StackName" -ForegroundColor Green
Deploy-Services -ComposeFile $ComposeFile -StackName $StackName

# Wait for database to be ready
Wait-DatabaseReady

Write-Host "=== Backend Deployment Complete ===" -ForegroundColor Green
Write-Host "Backend services deployed. Frontend services can now connect to backend services." -ForegroundColor Cyan
Write-Host "Backend services are internal-only and not accessible from external networks." -ForegroundColor Yellow 