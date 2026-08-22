#Requires -Version 7.0
<#
.SYNOPSIS
  Dual-register Terraform + PowerShell against Registry v1.1.0 and probe cross-provider join.
.NOTES
  Throwaway spike script. Not part of a shipping provider.
  Does not import analysis targets as modules for graph work — only Register-PSDrawIOProvider
  on manifests (declaration half). No HCL extraction. No Core.
#>
[CmdletBinding()]
param(
    [string]$RegistryPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'PS.DrawIO.Registry'),
    [string]$RegistryTag = 'v1.1.0',
    [string]$PowerShellProviderPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'PS.DrawIO.Provider.PowerShell'),
    [string]$PowerShellTag = 'v1.0.0'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$tfManifest = Join-Path $repoRoot 'src/PS.DrawIO.Provider.Terraform.psd1'
$psManifest = Join-Path $PowerShellProviderPath 'src/PS.DrawIO.Provider.PowerShell.psd1'

Write-Host "=== Cross-provider contract spike proof ==="
Write-Host "Terraform manifest:  $tfManifest"
Write-Host "PowerShell manifest: $psManifest"
Write-Host "Registry: $RegistryPath @ $RegistryTag"
Write-Host "PowerShell provider tag preference: $PowerShellTag"

function Write-RepoTagStatus {
    param([string]$Path, [string]$Label, [string]$Tag)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "$Label path missing: $Path"
        return
    }
    Push-Location $Path
    try {
        $head = (git rev-parse --short HEAD).Trim()
        $tagOk = $false
        try {
            $tagCommit = (git rev-parse --short $Tag).Trim()
            $tagOk = $true
        } catch {
            $tagCommit = '(tag missing)'
        }
        Write-Host "$Label HEAD=$head  ${Tag}=$tagCommit"
        if ($tagOk) {
            $diffStat = git diff --stat "$Tag" HEAD -- src/ 2>$null
            if ($diffStat) {
                Write-Host "WARNING: $Label src/ differs from ${Tag}:"
                Write-Host $diffStat
            } else {
                Write-Host "$Label src/ matches ${Tag} (ok to use working tree)."
            }
        }
    } finally {
        Pop-Location
    }
}

Write-RepoTagStatus -Path $RegistryPath -Label 'Registry' -Tag $RegistryTag
Write-RepoTagStatus -Path $PowerShellProviderPath -Label 'PowerShell provider' -Tag $PowerShellTag

$registryManifest = Join-Path $RegistryPath 'src/PS.DrawIO.Registry.psd1'
if (-not (Test-Path -LiteralPath $registryManifest)) {
    throw "Registry manifest not found: $registryManifest"
}
if (-not (Test-Path -LiteralPath $tfManifest)) {
    throw "Terraform spike manifest not found: $tfManifest"
}
if (-not (Test-Path -LiteralPath $psManifest)) {
    throw "PowerShell provider manifest not found: $psManifest"
}

Remove-Module PS.DrawIO.Registry -Force -ErrorAction SilentlyContinue
Remove-Module PS.DrawIO.Provider.PowerShell -Force -ErrorAction SilentlyContinue
Import-Module $registryManifest -Force
Write-Host "Imported PS.DrawIO.Registry $((Get-Module PS.DrawIO.Registry).Version)"

Write-Host "`n--- Public surface (join-related?) ---"
$exported = @((Get-Command -Module PS.DrawIO.Registry).Name | Sort-Object)
Write-Host ($exported -join ', ')

Write-Host "`n--- Conformance: Terraform spike ---"
$tfConforms = Test-PSDrawIOProviderConformance -Path $tfManifest
Write-Host "Terraform conformance: $tfConforms"
if (-not $tfConforms) { throw "Terraform conformance failed" }

Write-Host "`n--- Conformance: PowerShell provider ---"
$psConforms = Test-PSDrawIOProviderConformance -Path $psManifest
Write-Host "PowerShell conformance: $psConforms"
if (-not $psConforms) { throw "PowerShell conformance failed" }

Write-Host "`n--- Dual Register-PSDrawIOProvider ---"
$tfDecl = Register-PSDrawIOProvider -Path $tfManifest -Force
$psDecl = Register-PSDrawIOProvider -Path $psManifest -Force
Write-Host "Registered: $((@(Get-PSDrawIOProvider).ProviderName | Sort-Object) -join ', ')"
Write-Host "Terraform shapes: $((@($tfDecl.Shapes.Keys) | Sort-Object) -join ', ')"
Write-Host "PowerShell shapes: $((@($psDecl.Shapes.Keys) | Sort-Object) -join ', ')"

Write-Host "`n--- Resolve CrossProviderReference (Terraform) ---"
$cross = Resolve-PSDrawIOShape -Provider Terraform -Type CrossProviderReference
$cross | Format-List | Out-String | Write-Host
Write-Host "Cross shape keys: $((@($cross.Keys) | Sort-Object) -join ', ')"

Write-Host "`n--- Resolve far-end type on PowerShell (PSModule) ---"
$psModule = Resolve-PSDrawIOShape -Provider PowerShell -Type PSModule
$psModule | Format-List | Out-String | Write-Host

Write-Host "`n--- Probe: does registry expose far-end ownership on the edge? ---"
$ownershipKeys = @('FarEndProvider', 'FarEndType', 'TargetProvider', 'TargetType', 'Owner', 'OwnerProvider', 'ForeignProvider')
foreach ($k in $ownershipKeys) {
    $has = $cross.ContainsKey($k)
    Write-Host ("  shape has {0,-16} => {1}" -f $k, $has)
}

Write-Host "`n--- Probe: registry-only join (no Core, no graph objects) ---"
Write-Host "Attempt: use only Get-PSDrawIOProvider / Resolve-PSDrawIOShape to answer"
Write-Host "'which provider owns the far end of CrossProviderReference?'"
$joinAnswer = $null
$joinMethod = $null

# 1) First-class fields on the shape — none expected
foreach ($k in $ownershipKeys) {
    if ($cross.ContainsKey($k) -and $cross[$k]) {
        $joinAnswer = "$k=$($cross[$k])"
        $joinMethod = "shape field $k"
        break
    }
}

# 2) Metadata on Terraform declaration
if (-not $joinAnswer -and $tfDecl.Metadata -and $tfDecl.Metadata.Count -gt 0) {
    Write-Host "Terraform Metadata keys: $((@($tfDecl.Metadata.Keys) | Sort-Object) -join ', ')"
    $joinMethod = 'declaration Metadata (present)'
    $joinAnswer = ($tfDecl.Metadata | ConvertTo-Json -Compress)
} else {
    Write-Host "Terraform Metadata empty or absent (no join channel used)."
}

# 3) No registry API takes an edge type and returns another provider
if (-not $joinAnswer) {
    $joinMethod = 'none — registry has no join/ownership API'
    $joinAnswer = 'UNANSWERABLE from registry cmdlets alone'
}

Write-Host "Join method: $joinMethod"
Write-Host "Join answer: $joinAnswer"

Write-Host "`n--- Probe: can we Resolve-PSDrawIOShape across providers without knowing owner? ---"
try {
    # Intentionally wrong: ask Terraform for PSModule
    $null = Resolve-PSDrawIOShape -Provider Terraform -Type PSModule
    Write-Host "UNEXPECTED: Terraform resolved PSModule"
} catch {
    Write-Host "Expected failure resolving PSModule on Terraform: $($_.Exception.Message)"
}

Write-Host "`n--- Placeholder types on PowerShell declaration? ---"
foreach ($t in @('PSExternalCommand', 'PSUnresolved', 'PSModule', 'External')) {
    $declared = $psDecl.Shapes.ContainsKey($t)
    Write-Host ("  PowerShell declares {0,-20} => {1}" -f $t, $declared)
}

Write-Host "`n=== CROSS-PROVIDER PROOF COMPLETE ==="
Write-Host "Dual registration succeeded. Ownership join via registry alone: NO."
