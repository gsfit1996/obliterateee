param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,
    [string]$InstanceName = "obliteratus",
    [string]$Zone = "us-central1-a",
    [string]$MachineType = "e2-micro",
    [int]$DiskSizeGb = 30,
    [string]$DiskType = "pd-standard",
    [string]$ImageFamily = "ubuntu-2204-lts",
    [string]$ImageProject = "ubuntu-os-cloud",
    [string]$RepoUrl = "https://github.com/gsfit1996/obliterateee.git",
    [string]$RepoRef = "main",
    [int]$AppPort = 8080,
    [string]$AppDir = "/opt/obliteratus",
    [string]$AppUser = "obliteratus",
    [switch]$InstallOpsAgent
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$StartupScript = Join-Path $RepoRoot "deploy\\gcp\\startup-script.sh"

if (-not (Test-Path $StartupScript)) {
    throw "Could not find startup script at $StartupScript"
}

$gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloud) {
    throw "gcloud CLI is not installed or not on PATH."
}

function Get-ActiveGcloudAccount {
    $authJson = & $gcloud.Source auth list --format=json 2>$null
    if (-not $authJson) {
        return ""
    }

    try {
        $accounts = $authJson | ConvertFrom-Json
    } catch {
        return ""
    }

    $active = $accounts | Where-Object { $_.status -eq "ACTIVE" } | Select-Object -ExpandProperty account -First 1
    if (-not $active) {
        return ""
    }

    return $active.Trim()
}

$FirewallRule = "obliteratus-allow-http"
$FirewallTag = "obliteratus-server"
$Region = ($Zone -replace "-[a-z]$", "")

$activeAccount = Get-ActiveGcloudAccount
if (-not $activeAccount) {
    Write-Host "No active gcloud account found. Launching browser login ..."
    & $gcloud.Source auth login --brief
    $activeAccount = Get-ActiveGcloudAccount
    if (-not $activeAccount) {
        throw "No active gcloud account is available. Complete 'gcloud auth login' and rerun the script."
    }
}

Write-Host "Using gcloud account $activeAccount ..."

Write-Host "Setting gcloud project to $ProjectId ..."
& $gcloud.Source config set project $ProjectId | Out-Null

$requiredServices = @("compute.googleapis.com")
if ($InstallOpsAgent) {
    $requiredServices += @("logging.googleapis.com", "monitoring.googleapis.com")
}

Write-Host "Ensuring required Google Cloud APIs are enabled ..."
& $gcloud.Source services enable $requiredServices --project=$ProjectId | Out-Null

Write-Host "Ensuring default VPC network exists ..."
$existingNetwork = & $gcloud.Source compute networks describe default --project=$ProjectId 2>$null
if (-not $existingNetwork) {
    & $gcloud.Source compute networks create default `
        --project=$ProjectId `
        --subnet-mode=auto | Out-Null
}

Write-Host "Ensuring HTTP firewall rule exists ..."
$existingRule = & $gcloud.Source compute firewall-rules list `
    --project=$ProjectId `
    --filter="name=($FirewallRule)" `
    --format="value(name)" 2>$null
if (-not $existingRule) {
    & $gcloud.Source compute firewall-rules create $FirewallRule `
        --project=$ProjectId `
        --network=default `
        --direction=INGRESS `
        --action=ALLOW `
        --rules=tcp:80 `
        --source-ranges=0.0.0.0/0 `
        --target-tags=$FirewallTag | Out-Null
}

$metadata = @(
    "repo-url=$RepoUrl",
    "repo-ref=$RepoRef",
    "app-dir=$AppDir",
    "app-port=$AppPort",
    "app-user=$AppUser",
    "host-bind=127.0.0.1",
    "enable-nginx=1",
    ("install-ops-agent=" + ($(if ($InstallOpsAgent) { "1" } else { "0" })))
) -join ","

Write-Host "Creating Compute Engine VM $InstanceName in $Zone ..."
& $gcloud.Source compute instances create $InstanceName `
    --project=$ProjectId `
    --zone=$Zone `
    --machine-type=$MachineType `
    --network=default `
    --subnet=default `
    --maintenance-policy=MIGRATE `
    --provisioning-model=STANDARD `
    --scopes=https://www.googleapis.com/auth/cloud-platform `
    --tags=$FirewallTag `
    --image-family=$ImageFamily `
    --image-project=$ImageProject `
    --boot-disk-size="${DiskSizeGb}GB" `
    --boot-disk-type=$DiskType `
    --metadata=$metadata `
    --metadata-from-file=startup-script=$StartupScript

Write-Host
Write-Host "Instance created."
Write-Host "Startup script logs:"
Write-Host "  gcloud compute instances get-serial-port-output $InstanceName --zone $Zone --port 1"
Write-Host "Public IP:"
Write-Host "  gcloud compute instances describe $InstanceName --zone $Zone --format='get(networkInterfaces[0].accessConfigs[0].natIP)'"
Write-Host "API:"
Write-Host "  http://PUBLIC_IP/v1/models"
Write-Host
Write-Host "Free-tier note:"
Write-Host "  e2-micro is free only in us-central1/us-east1/us-west1 and only for light CPU workloads."
Write-Host "  For actually usable OBLITERATUS CPU hosting, switch to e2-standard-4 while you still have credits."
