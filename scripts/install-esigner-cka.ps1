param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  throw "RUNNER_TEMP is required"
}

$archive = Join-Path $env:RUNNER_TEMP "SSL.COM-eSigner-CKA_1.0.7.zip"
$expanded = Join-Path $env:RUNNER_TEMP "esigner-setup"
$expectedSha256 = "0f40f0ef0aa5c7d73b2d854ec0d2f2be551a6bbbd99cbbd886f7d3ef77c3327c"
$downloadUrl = "https://github.com/SSLcom/eSignerCKA/releases/download/v1.0.7/SSL.COM-eSigner-CKA_1.0.7.zip"

Invoke-WebRequest -Uri $downloadUrl -OutFile $archive
$actualSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
  throw "eSigner CKA archive checksum mismatch"
}

Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
$installers = @(
  Get-ChildItem -LiteralPath $expanded -Recurse -File -Filter "*.exe"
)
if ($installers.Count -ne 1) {
  throw "Expected exactly one eSigner CKA installer; found $($installers.Count)"
}

$installerSignature = Get-AuthenticodeSignature -LiteralPath $installers[0].FullName
if ($installerSignature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
  throw "eSigner CKA installer Authenticode is not trusted: $($installerSignature.Status)"
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$installerProcess = Start-Process -FilePath $installers[0].FullName `
  -ArgumentList @("/CURRENTUSER", "/VERYSILENT", "/SUPPRESSMSGBOXES", "/DIR=$InstallDir") `
  -Wait -PassThru
if ($installerProcess.ExitCode -ne 0) {
  throw "eSigner CKA installer failed with exit code $($installerProcess.ExitCode)"
}

$tool = Join-Path $InstallDir "eSignerCKATool.exe"
if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
  throw "eSigner CKA command-line tool was not installed"
}

Write-Host "Installed the checksum-pinned, Authenticode-trusted eSigner CKA package."
Write-Output $tool
