param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

foreach ($name in @("ES_USERNAME", "ES_PASSWORD", "ES_TOTP_SECRET", "ES_PUBLISHER_NAME")) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "$name is required"
  }
}

Write-Host "::add-mask::$env:ES_USERNAME"
Write-Host "::add-mask::$env:ES_PASSWORD"
Write-Host "::add-mask::$env:ES_TOTP_SECRET"

$masterKey = Join-Path $InstallDir "master.key"
$installerScript = Join-Path $PSScriptRoot "install-esigner-cka.ps1"
$tool = & $installerScript -InstallDir $InstallDir

& $tool config -mode "product" -user $env:ES_USERNAME -pass $env:ES_PASSWORD `
  -totp $env:ES_TOTP_SECRET -key $masterKey -r | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "eSigner CKA account configuration failed"
}
& $tool unload | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "eSigner CKA certificate unload failed"
}
& $tool load | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "eSigner CKA certificate load failed"
}

$certificates = @(
  Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Where-Object {
      $_.HasPrivateKey -and
      $_.NotAfter -gt (Get-Date) -and
      $_.GetNameInfo(
        [System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName,
        $false
      ) -eq $env:ES_PUBLISHER_NAME
    }
)
if ($certificates.Count -ne 1) {
  throw "Expected exactly one usable eSigner certificate for ES_PUBLISHER_NAME; found $($certificates.Count)"
}

Write-Output ([PSCustomObject]@{
  Thumbprint = $certificates[0].Thumbprint
  Subject = $certificates[0].Subject
})
