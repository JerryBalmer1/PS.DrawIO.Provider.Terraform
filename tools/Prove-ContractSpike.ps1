#Requires -Version 7.0
<#
.SYNOPSIS
  End-to-end proof that the Terraform spike manifest works against Registry v1.0.0.
.NOTES
  Throwaway spike script. Not part of a shipping provider.
#>
[CmdletBinding()]
param(
    [string]$RegistryPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'PS.DrawIO.Registry'),
    [string]$RegistryTag = 'v1.0.0'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $repoRoot 'src/PS.DrawIO.Provider.Terraform.psd1'

Write-Host "=== Terraform contract spike proof ==="
Write-Host "Manifest: $manifestPath"
Write-Host "Registry: $RegistryPath @ $RegistryTag"

Push-Location $RegistryPath
try {
    $head = (git rev-parse --short HEAD).Trim()
    $tagCommit = (git rev-parse --short $RegistryTag).Trim()
    Write-Host "Registry HEAD=$head  $RegistryTag=$tagCommit"
    # Prefer tagged tree if checkout differs; import from working tree src (tag content matches src/ at v1.0.0).
    $diffStat = git diff --stat "$RegistryTag" HEAD -- src/
    if ($diffStat) {
        Write-Host "WARNING: Registry src/ differs from ${RegistryTag}:"
        Write-Host $diffStat
    } else {
        Write-Host "Registry src/ matches ${RegistryTag} (ok to import working tree)."
    }
} finally {
    Pop-Location
}

$registryManifest = Join-Path $RegistryPath 'src/PS.DrawIO.Registry.psd1'
if (-not (Test-Path -LiteralPath $registryManifest)) {
    throw "Registry manifest not found: $registryManifest"
}

Remove-Module PS.DrawIO.Registry -Force -ErrorAction SilentlyContinue
Import-Module $registryManifest -Force
Write-Host "Imported PS.DrawIO.Registry $((Get-Module PS.DrawIO.Registry).Version)"

Write-Host "`n--- Test-PSDrawIOProviderConformance ---"
$conforms = Test-PSDrawIOProviderConformance -Path $manifestPath
Write-Host "Conformance result: $conforms"
if (-not $conforms) {
    throw "Conformance failed for $manifestPath"
}

Write-Host "`n--- Register-PSDrawIOProvider ---"
$declaration = Register-PSDrawIOProvider -Path $manifestPath -Force
$declaration | Format-List ProviderName, ContractVersion, Capabilities | Out-String | Write-Host
Write-Host "Shape keys: $((@($declaration.Shapes.Keys) | Sort-Object) -join ', ')"

Write-Host "`n--- Resolve-PSDrawIOShape node: TfResource ---"
$node = Resolve-PSDrawIOShape -Provider Terraform -Type TfResource
$node | Format-List | Out-String | Write-Host

Write-Host "`n--- Resolve-PSDrawIOShape edge: ImplicitReference ---"
$edge = Resolve-PSDrawIOShape -Provider Terraform -Type ImplicitReference
$edge | Format-List | Out-String | Write-Host

Write-Host "`n--- Test-PSDrawIOCapability ---"
foreach ($cap in @('Shapes', 'Links', 'LayoutHints', 'Analysis')) {
    $ok = Test-PSDrawIOCapability -Provider Terraform -Name $cap
    Write-Host ("  {0,-12} => {1}" -f $cap, $ok)
}

Write-Host "`n=== PROOF COMPLETE ==="
