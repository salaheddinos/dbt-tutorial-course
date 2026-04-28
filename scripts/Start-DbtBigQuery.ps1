param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectId,

    [Parameter(Mandatory = $false)]
    [switch]$Authenticate,

    [Parameter(Mandatory = $false)]
    [switch]$RunDebug
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$profilesDir = Join-Path $repoRoot "answers"
$venvDbt = Join-Path $repoRoot ".dbt-course-2\Scripts\dbt.exe"
$adcPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"

$gcloudCandidates = @(
    "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin",
    "C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin",
    (Join-Path $env:LOCALAPPDATA "Google\Cloud SDK\google-cloud-sdk\bin")
)

$gcloudBin = $gcloudCandidates | Where-Object { Test-Path (Join-Path $_ "gcloud.cmd") } | Select-Object -First 1

if (-not $gcloudBin) {
    throw "Google Cloud SDK was not found in the standard install locations."
}

if (($env:Path -split ';') -notcontains $gcloudBin) {
    $env:Path = "$gcloudBin;$env:Path"
}

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw "gcloud is still not available in this shell after adding the SDK path."
}

if (-not $ProjectId -and $env:BIGQUERY_PROJECT) {
    $ProjectId = $env:BIGQUERY_PROJECT
}

if ($ProjectId) {
    $env:BIGQUERY_PROJECT = $ProjectId
}

$env:DBT_PROFILES_DIR = $profilesDir

Write-Host "Google Cloud SDK path: $gcloudBin"
Write-Host "DBT profiles dir: $env:DBT_PROFILES_DIR"

if ($env:BIGQUERY_PROJECT) {
    Write-Host "BIGQUERY_PROJECT: $env:BIGQUERY_PROJECT"
} else {
    Write-Warning "BIGQUERY_PROJECT is not set. Pass -ProjectId <your-gcp-project-id>."
}

if ($Authenticate) {
    Write-Host "Starting Application Default Credentials login..."
    & gcloud auth application-default login
}

if (Test-Path $adcPath) {
    Write-Host "ADC file found: $adcPath"
} else {
    Write-Warning "ADC file not found. Run: gcloud auth application-default login"
}

if ($RunDebug) {
    if (-not (Test-Path $venvDbt)) {
        throw "dbt executable not found at $venvDbt"
    }

    if (-not $env:BIGQUERY_PROJECT) {
        throw "Cannot run dbt debug without BIGQUERY_PROJECT. Pass -ProjectId <your-gcp-project-id>."
    }

    & $venvDbt debug --project-dir $profilesDir --profiles-dir $profilesDir
}
