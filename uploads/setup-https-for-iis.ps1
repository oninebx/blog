[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $siteName,
    
    [Parameter(Mandatory = $true)]
    [string] $sitePath,

    [Parameter(Mandatory = $true)]
    [string] $dnsName,

    [Parameter(Mandatory = $true)]
    [int] $port,
    [int] $validYears = 3,

    [string]$outputFolder = "C:\ProgramData\${siteName}",
    [string]$password = "${dnsName}123"
)

Write-Host "🔧 Creating self-signed certificate for $dnsName ..."

# ==============================
# Setup valid environment
# ==============================

# Validate

if (!(Test-Path $sitePath)) {
    Write-Error "❌ The specified site path '$sitePath' does not exist. Please create it first."
    exit 1
}

$site = Get-Website | Where-Object { $_.Name -eq $siteName }
if ($site) {
    Write-Error "❌ IIS site '$siteName' exists.. Please change the name and try again. Exiting."
    exit 1
}

$existingBinding = Get-WebBinding | Where-Object { 
    $_.protocol -eq "https" -and ($_.bindingInformation -match ":${port}:") 
}
if ($existingBinding) {
    # Safely get site names bound to the port
    $sites = $existingBinding | ForEach-Object { $_.Name }
    Write-Error "❌ Port $port is already bound by site(s): $($sites -join ', '). Exiting."
    exit 1
} else {
    Write-Host "✔ Port $port is free for HTTPS binding."
}

# Create or recreate output folder
if (Test-Path $outputFolder) {
    Write-Host "🧹 Removing existing folder: $outputFolder"
    Remove-Item -Path $outputFolder -Recurse -Force
}

Write-Host "📁 Creating folder: $outputFolder"
New-Item -ItemType Directory -Path $outputFolder | Out-Null

$fileName = $siteName.ToLower()

# ==============================
# Create Self-Signed Certificate for local HTTPS
# ==============================

# Calculate expiry date
$expireDate = (Get-Date).AddYears($ValidYears)

# Delete old certificate(if exists)
$certStore = "Cert:\LocalMachine\My"
$existing = Get-ChildItem $certStore | Where-Object { $_.Subject -like "*CN=$dnsName*" }
if ($existing) {
    Write-Host "🧹 Removing existing certificate for $dnsName ..."
    $existing | Remove-Item
}

# Generate new certificate
$cert = New-SelfSignedCertificate `
    -DnsName $dnsName `
    -FriendlyName "$hostname Local Development Certificate" `
    -CertStoreLocation $certStore `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -HashAlgorithm sha256 `
    -NotAfter $expireDate

Write-Host "✅ Certificate created: $($cert.Subject)"
Write-Host "   Thumbprint: $($cert.Thumbprint)"
Write-Host "   Store: $certStore"

# ==============================
# Export .pfx and .cer files (for reuse in front-end or IIS)
# ==============================
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

$pfxPath = Join-Path $outputFolder "$fileName.pfx"
$cerPath = Join-Path $outputFolder "$fileName.cer"

$securePwd = ConvertTo-SecureString -String $password -Force -AsPlainText

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePwd | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

Write-Host "📁 Exported to:"
Write-Host "   $pfxPath"
Write-Host "   $cerPath"

# ==============================
# Add to Trusted Root CA (optional but recommended for HTTPS trust)
# ==============================
$rootStore = "Cert:\LocalMachine\Root"

$rootExisting = Get-ChildItem $rootStore | Where-Object { $_.Subject -like "*CN=$dnsName*" }
if ($rootExisting) {
    Write-Host "🧹 Removing existing root certificate for $dnsName ..."
    $rootExisting | Remove-Item
}

Write-Host "🔒 Adding certificate to Trusted Root Certification Authorities..."
Import-Certificate -FilePath $cerPath -CertStoreLocation $rootStore | Out-Null
Write-Host "✅ Added to Trusted Root store."

# ==============================
# Add hosts mapping
# ==============================
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$ipAddress = "127.0.0.1"
$existingEntry = Get-Content $hostsPath | Where-Object { $_ -match "\s+$dnsName(\s|$)" }

if (-not $existingEntry) {
    Write-Host "📝 Adding hosts entry for $dnsName ..."
    Add-Content -Path $hostsPath -Value "`r`n$ipAddress`t$dnsName"
    Write-Host "✅ Hosts entry added."
} else {
    Write-Host "✅ Hosts entry for $dnsName already exists."
}

Write-Host "`n🎉 All done! You can now use https://$dnsName"

# ==============================
# Setup IIS website
# ==============================

# Create if App Pool not exists
New-WebAppPool -Name $siteName

# Configure App Pool for ASP.NET Core
Set-ItemProperty "IIS:\AppPools\$siteName" -Name "managedRuntimeVersion" -Value ""  # No CLR
Set-ItemProperty "IIS:\AppPools\$siteName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"

Write-Host "✅ App Pool '$siteName' created and configured for ASP.NET Core."

# Create Website
New-Website -Name $siteName -Port 10080 -PhysicalPath $sitePath -HostHeader $hostName -ApplicationPool $siteName
Write-Host "🌐 Created IIS website '$siteName' on port 10080"

# Remove the dummy HTTP binding
$httpBindings = Get-WebBinding -Name $siteName | Where-Object { $_.protocol -eq "http" }
if ($httpBindings) { 
    $httpBindings | Remove-WebBinding 
    Write-Host "🌐 Remove IIS website '$siteName' dummy http binding on port 10080"
}

# Remove existing HTTPS bindings if any
$bindings = Get-WebBinding -Name $siteName | Where-Object { $_.bindingInformation -like "*:${port}:*" }
if ($bindings) {
    Write-Host "Removing existing HTTPS bindings..."
    $bindings | Remove-WebBinding
}

# Add new HTTPS binding
New-WebBinding -Name $siteName -Protocol https -Port $port -HostHeader $dnsName
Write-Host "🔗 Added HTTPS binding on port $port"

# Bind certificate
$bindingPath = "IIS:\SslBindings\0.0.0.0!$port"
if (!(Get-Item $bindingPath -ErrorAction SilentlyContinue)) {
    New-Item -Path $bindingPath -Thumbprint $cert.Thumbprint -SSLFlags 0
    Write-Host "🔒 Bound certificate to HTTPS"
} else {
    Write-Host "Certificate binding already exists on port $port"
}

Write-Host "`n✅ IIS backend site '$siteName' is ready at https://${dnsName}:$port/"

# ==============================
# Export cer and key files for frontend application
# ==============================

# Check if openssl is ready
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Error "❌ OpenSSL not found. Please install OpenSSL and ensure it is in your PATH."
    Write-Host "   Recommended Windows version: https://slproweb.com/products/Win32OpenSSL.html"
    exit 1
} else {
    Write-Host "✅ OpenSSL detected."
}

$pemPath = Join-Path $OutputFolder "$fileName-cert.pem"
$keyPath = Join-Path $OutputFolder "$fileName-key.pem"

# Generate PEM and KEY
Write-Host "🔧 Converting PFX to PEM and KEY using OpenSSL..."

# PEM (certificate only)
& openssl pkcs12 -in $pfxPath -clcerts -nokeys -out $pemPath -passin pass:$Password
if ($LASTEXITCODE -ne 0) { Write-Error "❌ Failed to create PEM"; exit 1 }

# Private KEY
& openssl pkcs12 -in $pfxPath -nocerts -nodes -out $keyPath -passin pass:$Password
if ($LASTEXITCODE -ne 0) { Write-Error "❌ Failed to extract private key"; exit 1 }

Write-Host "✅ PEM and KEY files created successfully:"
Write-Host "   Certificate: $pemPath"
Write-Host "   Private Key: $keyPath"

# Create .env.development.local for React (Vite)
$envFile = Join-Path $OutputFolder ".env.development.local"
$envContent = @"
SSL_KEY_FILE=$keyPath
SSL_CRT_FILE=$pemPath
HOST=$dnsName
PORT=$($port + 1)
"@
Set-Content -Path $envFile -Value $envContent -Encoding UTF8

Write-Host "`n✅ Done!"
Write-Host "   - Certificate: $cerPath"
Write-Host "   - PFX: $pfxPath"
Write-Host "   - Key: $keyPath"
Write-Host "   - Env file: $envFile"
Write-Host "`n🎯 Next step:"
Write-Host "   1. In your React (Vite) project root, copy the .env.development.local file."
Write-Host "   2. Start your dev server: npm run dev"
Write-Host "   3. Change port if it is already being used"
