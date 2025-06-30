# UnCloud - Update Compose Images Script
# This script updates docker-compose files to use built images

param(
    [string]$Registry = "uncloud",
    [string]$Tag = "latest"
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

# Function to update image in docker-compose file
function Update-ComposeImage {
    param(
        [string]$ComposeFile,
        [string]$ServiceName,
        [string]$NewImage
    )
    
    if (Test-Path $ComposeFile) {
        Write-Host "Updating $ServiceName in $ComposeFile..." -ForegroundColor Green
        
        $content = Get-Content $ComposeFile -Raw
        
        # Replace dummy image with built image
        $pattern = "image:\s*dummy/$ServiceName`:[^\s]*"
        $replacement = "image: $NewImage"
        
        $newContent = $content -replace $pattern, $replacement
        
        if ($newContent -ne $content) {
            Set-Content -Path $ComposeFile -Value $newContent -NoNewline
            Write-Host "✓ Updated $ServiceName to use $NewImage" -ForegroundColor Green
        } else {
            Write-Host "⚠ No changes needed for $ServiceName" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Compose file not found: $ComposeFile" -ForegroundColor Red
    }
}

# Function to update service-specific compose files
function Update-ServiceComposeFiles {
    param(
        [string]$Registry,
        [string]$Tag
    )
    
    $Services = @(
        @{
            Name = "passwordmanager"
            ComposeFile = "services\frontend\passwordmanager\docker-compose.yml"
        },
        @{
            Name = "syncservice"
            ComposeFile = "services\frontend\syncservice\docker-compose.yml"
        },
        @{
            Name = "website"
            ComposeFile = "services\frontend\website\docker-compose.yml"
        },
        @{
            Name = "pwdmanager-backend"
            ComposeFile = "services\backend\pwdmanager\docker-compose.yml"
        },
        @{
            Name = "email-backend"
            ComposeFile = "services\backend\email\docker-compose.yml"
        },
        @{
            Name = "nas"
            ComposeFile = "services\backend\nas\docker-compose.yml"
        }
    )
    
    foreach ($Service in $Services) {
        $ComposeFile = Join-Path $PSScriptRoot ".." $Service.ComposeFile
        $NewImage = "$Registry/$($Service.Name):$Tag"
        
        Update-ComposeImage -ComposeFile $ComposeFile -ServiceName $Service.Name -NewImage $NewImage
    }
}

# Main execution
Write-Host "=== UnCloud Update Compose Images ===" -ForegroundColor Magenta
Write-Host "Registry: $Registry" -ForegroundColor Cyan
Write-Host "Tag: $Tag" -ForegroundColor Cyan

# Update service-specific compose files
Update-ServiceComposeFiles -Registry $Registry -Tag $Tag

Write-Host "=== Update Complete ===" -ForegroundColor Green
Write-Host "All docker-compose files have been updated to use built images." -ForegroundColor Cyan 