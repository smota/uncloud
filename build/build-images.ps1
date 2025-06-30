# UnCloud - Docker Image Build Script
# This script builds all Docker images for the UnCloud infrastructure

param(
    [string]$Registry = "uncloud",
    [string]$Tag = "latest",
    [switch]$Push = $false,
    [switch]$NoCache = $false,
    [string]$Platform = "linux/amd64"
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

# Function to build Docker image
function Build-DockerImage {
    param(
        [string]$ServiceName,
        [string]$DockerfilePath,
        [string]$ContextPath,
        [string]$Registry,
        [string]$Tag,
        [bool]$NoCache
    )
    
    $ImageName = "$Registry/$ServiceName"
    $FullTag = "$ImageName`:$Tag"
    
    Write-Host "Building $ServiceName..." -ForegroundColor Green
    Write-Host "  Image: $FullTag" -ForegroundColor Cyan
    Write-Host "  Dockerfile: $DockerfilePath" -ForegroundColor Cyan
    Write-Host "  Context: $ContextPath" -ForegroundColor Cyan
    
    $buildArgs = @(
        "build",
        "--platform", $Platform,
        "--file", $DockerfilePath,
        "--tag", $FullTag
    )
    
    if ($NoCache) {
        $buildArgs += "--no-cache"
    }
    
    $buildArgs += $ContextPath
    
    $result = docker $buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully built $FullTag" -ForegroundColor Green
        
        if ($Push) {
            Write-Host "Pushing $FullTag..." -ForegroundColor Yellow
            $pushResult = docker push $FullTag
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Successfully pushed $FullTag" -ForegroundColor Green
            } else {
                Write-Host "✗ Failed to push $FullTag" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "✗ Failed to build $FullTag" -ForegroundColor Red
        return $false
    }
    
    return $true
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

# Main execution
Write-Host "=== UnCloud Docker Image Build ===" -ForegroundColor Magenta
Write-Host "Registry: $Registry" -ForegroundColor Cyan
Write-Host "Tag: $Tag" -ForegroundColor Cyan
Write-Host "Platform: $Platform" -ForegroundColor Cyan
Write-Host "Push: $Push" -ForegroundColor Cyan
Write-Host "No Cache: $NoCache" -ForegroundColor Cyan

# Check if Docker is running
if (-not (Test-DockerRunning)) {
    Write-Host "ERROR: Docker is not running. Please start Docker and try again." -ForegroundColor Red
    exit 1
}

# Define services to build
$Services = @(
    @{
        Name = "passwordmanager"
        Dockerfile = "build\dockerfiles\passwordmanager\Dockerfile"
        Context = "services\frontend\passwordmanager"
    },
    @{
        Name = "syncservice"
        Dockerfile = "build\dockerfiles\syncservice\Dockerfile"
        Context = "services\frontend\syncservice"
    },
    @{
        Name = "website"
        Dockerfile = "build\dockerfiles\website\Dockerfile"
        Context = "services\frontend\website"
    },
    @{
        Name = "pwdmanager-backend"
        Dockerfile = "build\dockerfiles\pwdmanager-backend\Dockerfile"
        Context = "services\backend\pwdmanager"
    },
    @{
        Name = "email-backend"
        Dockerfile = "build\dockerfiles\email-backend\Dockerfile"
        Context = "services\backend\email"
    },
    @{
        Name = "nas"
        Dockerfile = "build\dockerfiles\nas\Dockerfile"
        Context = "services\backend\nas"
    }
)

# Build all services
$SuccessCount = 0
$TotalCount = $Services.Count

foreach ($Service in $Services) {
    $DockerfilePath = Join-Path $PSScriptRoot ".." $Service.Dockerfile
    $ContextPath = Join-Path $PSScriptRoot ".." $Service.Context
    
    if (Test-Path $DockerfilePath) {
        if (Build-DockerImage -ServiceName $Service.Name -DockerfilePath $DockerfilePath -ContextPath $ContextPath -Registry $Registry -Tag $Tag -NoCache $NoCache) {
            $SuccessCount++
        }
    } else {
        Write-Host "✗ Dockerfile not found: $DockerfilePath" -ForegroundColor Red
    }
}

# Summary
Write-Host "=== Build Summary ===" -ForegroundColor Magenta
Write-Host "Successfully built: $SuccessCount/$TotalCount images" -ForegroundColor $(if ($SuccessCount -eq $TotalCount) { "Green" } else { "Yellow" })

if ($SuccessCount -eq $TotalCount) {
    Write-Host "✓ All images built successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some images failed to build" -ForegroundColor Red
    exit 1
} 