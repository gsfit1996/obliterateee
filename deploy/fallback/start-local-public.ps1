param(
    [int]$Port = 8080,
    [string]$Host = "localhost"
)

$ErrorActionPreference = "Stop"

function Resolve-PythonExe {
    $candidates = @(
        (Join-Path $RepoRoot ".venv314\\Scripts\\python.exe"),
        (Join-Path $RepoRoot ".venv\\Scripts\\python.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return $python.Source
    }
    throw "Could not find a Python interpreter. Create .venv314/.venv or install Python."
}

function Ensure-Cloudflared {
    $existing = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing.Source
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "cloudflared is not installed and winget is unavailable. Install cloudflared manually first."
    }

    Write-Host "Installing cloudflared via winget..."
    & $winget.Source install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements

    $installed = Get-Command cloudflared -ErrorAction SilentlyContinue
    if (-not $installed) {
        throw "cloudflared installation did not complete successfully."
    }
    return $installed.Source
}

function Wait-Url([string]$Url, [int]$TimeoutSeconds = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 5
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
                return
            }
        } catch {
        }
        Start-Sleep -Seconds 2
    }
    throw "Timed out waiting for $Url"
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
Set-Location $RepoRoot

$listen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listen) {
    $pythonExe = Resolve-PythonExe
    Write-Host "Starting local OBLITERATUS server on http://${Host}:$Port ..."
    $server = Start-Process -FilePath $pythonExe `
        -ArgumentList @("app.py", "--host", $Host, "--port", "$Port") `
        -WorkingDirectory $RepoRoot `
        -PassThru
    Write-Host "Local server PID: $($server.Id)"
    Wait-Url -Url "http://${Host}:$Port/"
} else {
    Write-Host "Reusing existing listener on port $Port."
}

$cloudflaredExe = Ensure-Cloudflared
Write-Host "Opening Cloudflare Quick Tunnel for http://${Host}:$Port ..."
Write-Host "This is development-only and not suitable for production."
& $cloudflaredExe tunnel --url "http://${Host}:$Port"
