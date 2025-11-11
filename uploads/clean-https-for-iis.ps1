<#
.SYNOPSIS
Cleans up all IIS and certificate configurations created by Setup-IIS-Backend.ps1.

.DESCRIPTION
This script removes:
- IIS website and application pool
- HTTPS bindings
- Certificate bindings (IIS:\SslBindings)
- Self-signed certificates for the specified host name
- Exported certificate files (.cer, .pfx)
- Output folder (optional)

.EXAMPLE
.\Cleanup-IIS-Backend.ps1 -siteName "MyAspNetApp" -hostName "demo.local" -port 443
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $siteName,

    [Parameter(Mandatory = $true)]
    [string] $hostName,

    [Parameter(Mandatory = $true)]
    [int] $port,

    [string] $outputFolder = "C:\ProgramData\$siteName",

    [switch] $removeOutputFolder = $true
)

Import-Module WebAdministration

Write-Host "=== Cleaning up IIS HTTPS setup for '$siteName' ===" -ForegroundColor Cyan
Write-Host "Host Name: $hostName"
Write-Host "Port: $port"
Write-Host "Output Folder: $outputFolder"
Write-Host "============================================`n"

# =====================================================
# 1️ Remove IIS website
# =====================================================
Write-Host "🌐 Removing IIS website..."
$website = Get-Website | Where-Object { $_.Name -eq $siteName }
if ($website) {
    Stop-Website -Name $siteName -ErrorAction SilentlyContinue
    Remove-Website -Name $siteName -ErrorAction SilentlyContinue
    Write-Host "✅ Website '$siteName' removed."
} else {
    Write-Host "✔ Website '$siteName' not found. Skipping."
}

# =====================================================
# 2️ Remove IIS application pool
# =====================================================
Write-Host "`n⚙ Removing IIS Application Pool..."
$appPool = Get-ChildItem IIS:\AppPools | Where-Object { $_.Name -eq $siteName }
if ($appPool) {
    Stop-WebAppPool -Name $siteName -ErrorAction SilentlyContinue
    Remove-WebAppPool -Name $siteName -ErrorAction SilentlyContinue
    Write-Host "✅ Application Pool '$siteName' removed."
} else {
    Write-Host "✔ Application Pool '$siteName' not found. Skipping."
}

# =====================================================
# 3️ Remove certificate binding (IIS:\SslBindings)
# =====================================================
Write-Host "`n🧹 Removing certificate binding (IIS:\SslBindings)..."
$ip = "0.0.0.0"
$bindingPath = "IIS:\SslBindings\$ip!$port"

if (Test-Path $bindingPath) {
    Remove-Item $bindingPath -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Certificate binding removed on port $port"
} else {
    Write-Host "✔ No certificate binding found on port $port"
}

# =====================================================
# 4️ Remove certificate (from Personal + Root)
# =====================================================
Write-Host "`n🔒 Removing certificate(s) for CN=$hostName ..."

# Personal store
$personalCerts = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*CN=$hostName*" }
foreach ($c in $personalCerts) {
    Remove-Item -Path "Cert:\LocalMachine\My\$($c.Thumbprint)" -ErrorAction SilentlyContinue
    Write-Host "🗑 Removed from Personal store: $($c.Subject)"
}

# Root store
$rootCerts = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*CN=$hostName*" }
foreach ($c in $rootCerts) {
    Remove-Item -Path "Cert:\LocalMachine\Root\$($c.Thumbprint)" -ErrorAction SilentlyContinue
    Write-Host "🗑 Removed from Root store: $($c.Subject)"
}

if (-not $personalCerts -and -not $rootCerts) {
    Write-Host "✔ No certificates found for CN=$hostName"
}

# =====================================================
# 5️ Remove exported certificate files
# =====================================================
Write-Host "`n📦 Cleaning exported certificate files..."
$files = @(
    (Join-Path $outputFolder "$($siteName.ToLower()).cer"),
    (Join-Path $outputFolder "$($siteName.ToLower()).pfx")
) | Where-Object { Test-Path $_ }

foreach ($file in $files) {
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    Write-Host "🗑 Deleted: $file"
}

if (-not $files) {
    Write-Host "✔ No exported cert files found."
}

# =====================================================
# 6️ Optionally remove output folder
# =====================================================
if ($removeOutputFolder -and (Test-Path $outputFolder)) {
    Write-Host "`n📂 Removing output folder: $outputFolder"
    Remove-Item -Path $outputFolder -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Output folder removed."
}

# =====================================================
# 7 Remove entry from hosts for host name
# =====================================================
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$ipAddress = "127.0.0.1" 


$hostsContent = Get-Content $hostsPath
$updatedContent = $hostsContent | Where-Object { $_ -notmatch "^\s*$ipAddress\s+$hostName(\s|$)" -and $_ -notmatch "\s+$hostName(\s|$)" }
    
if ($hostsContent.Count -ne $updatedContent.Count) {
    Write-Host "🧹 Removing hosts entry for $hostName ..."
    Set-Content -Path $hostsPath -Value $updatedContent
    Write-Host "✅ Entry for $hostName removed."
} else {
    Write-Host "ℹ️ No entry found for $hostName."
}


# =====================================================
# ✅ Completion
# =====================================================
Write-Host "`n✅ Cleanup complete for site '$siteName'."
Write-Host "All IIS components, bindings, and certificates removed successfully."
Write-Host "============================================" -ForegroundColor Cyan
