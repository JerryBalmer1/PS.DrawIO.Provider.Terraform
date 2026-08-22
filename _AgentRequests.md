# Agent request results

## Task: cross-provider reference spike at b7031e4

**Status:** complete (declaration + dual-register proof only; no extraction/Core/join implementation)  
**Date:** 2026-08-21  
**Base HEAD:** `b7031e4`  
**Working tree after spike:** uncommitted edits listed below (no commit/push)

### Files touched

| Path | Action |
|---|---|
| `src/PS.DrawIO.Provider.Terraform.psd1` | Added `CrossProviderReference` edge shape (`Edge=$true` + Style); comments on missing ownership fields |
| `tools/Prove-CrossProviderSpike.ps1` | **New** — dual-register Terraform + PowerShell @ Registry v1.1.0; ownership/join probes |
| `tools/proof-cross-provider-transcript.txt` | **New** — raw proof transcript |
| `docs/SPIKE-FINDINGS-CROSS-PROVIDER.md` | **New** — answers Q1–Q7 with quotes |
| `_AgentRequests.md` | This report |

### Deliberately NOT done

- No edits under `PS.DrawIO.Registry` or `PS.DrawIO.Provider.PowerShell`
- No HCL parsing / extraction / graph builder
- No Core join implementation
- No contract change, no `NodeTypes`/`EdgeTypes`
- No build/CI/SIGNOFF
- No commit / push / PR
- Did not write fake first-class `FarEndProvider` into the shape as if it were contract (comments only; proof shows keys `Edge`, `Style` only)

---

## Step 1 — Evidence quotes

### Registry CONTRACT.md (declare fields)

`PrivateData.PSDrawIO` documents:

- `ContractVersion` (major; must match registry)
- `ProviderName` (PascalCase)
- `Capabilities` (non-empty list)
- `Shapes` — semantic type → opaque declaration; registry stores, never renders/layout
- `Metadata` — optional opaque hashtable; stored/returned; **unvalidated** beyond hashtable-when-present

Closing line: *“The registry returns declarations to Core. Providers never execute during shape resolution.”*

### ConvertTo-PSDrawIODeclaration.ps1 (stored object)

Required keys on `PSDrawIO`: `ContractVersion`, `ProviderName`, `Capabilities`.  
Optional: `Shapes` → `{}`, `Metadata` → `{}`.  
Returned PSCustomObject:

```text
PSTypeName, ProviderName, ContractVersion, Capabilities, Shapes, Metadata
```

No ownership / far-end / join fields. Shape entry validation: non-empty key + non-null value only.

### PowerShell DOMAIN-MODEL + ADR 0001 (placeholders)

- Nodes: source types + **`PSExternalCommand`** / **`PSUnresolved` placeholders** so every edge endpoint exists in `Nodes`.
- Edges: `Internal` / `External` / `Unresolved`; endpoints are node **Ids**; external edges carry **`ExternalKind`**: `BuiltIn` | `Module` | `Unknown`.
- ADR 0001: closed graph via placeholders; reusable contract concern for future providers.

### PowerShell manifest (declaration half)

Shape keys only: `PSFunction`, `PSClass`, `PSEnum`, `PSModule`, `Internal`, `External`, `Unresolved`, `Inherits` (edges use `Edge = $true`).  
**Does not declare** `PSExternalCommand` or `PSUnresolved` — placeholders are graph-schema, not registry shapes. Proof: `PSExternalCommand => False`, `PSUnresolved => False`.

### Registry public surface / three-way split

Public: Register / Get / Unregister / Resolve-Shape / Test-Capability / Test-Name / Test-Conformance / New-Provider.  
`Resolve-PSDrawIOShape -Provider -Type` returns **one** provider’s shape blob.  
`REGISTRY.md` §4: Provider declares → Registry stores → **Core applies**. No graph join API.

### Tags used

| Component | Tag | Commit | src vs tag |
|---|---|---|---|
| Registry | `v1.1.0` | `e6c19e8` | matches (HEAD `ce38ef1`) |
| PowerShell provider | `v1.0.0` | `3c26691` | matches (HEAD `facb1ed`) |

---

## Step 2 — Manifest attempt (ownership)

Wanted: edge declaring far end **PowerShell / PSModule**.

**Result:** no first-class field. Stopped inventing contract keys.  
Added only:

```powershell
CrossProviderReference = @{
    Edge  = $true
    Style = 'endArrow=open;dashed=1;dashPattern=2 2;'
}
```

Comments document that `FarEndProvider` / `FarEndType` would be private convention if stuffed into the opaque hashtable.  
`Metadata` join side-channel **not** used (same cost as `Edge = $true`); documented in findings.

---

## Step 3 — Raw dual-register proof (summary; full file on disk)

Script: `tools/Prove-CrossProviderSpike.ps1`  
Transcript: `tools/proof-cross-provider-transcript.txt`

```text
Imported PS.DrawIO.Registry 1.1.0
Public surface: Get-PSDrawIOProvider, New-PSDrawIOProvider, Register-PSDrawIOProvider,
  Resolve-PSDrawIOShape, Test-PSDrawIOCapability, Test-PSDrawIOName,
  Test-PSDrawIOProviderConformance, Unregister-PSDrawIOProvider

Terraform conformance: True
PowerShell conformance: True

Registered: PowerShell, Terraform
Terraform shapes: … CrossProviderReference …
PowerShell shapes: External, Inherits, Internal, PSClass, PSEnum, PSFunction, PSModule, Unresolved

CrossProviderReference keys: Edge, Style
Ownership key probes (FarEndProvider, FarEndType, TargetProvider, TargetType, Owner, …): all False
Terraform Metadata empty
Join method: none — registry has no join/ownership API
Join answer: UNANSWERABLE from registry cmdlets alone

Resolve PSModule on Terraform: throws (does not declare shape PSModule)
PSExternalCommand declared on PowerShell: False
PSUnresolved declared on PowerShell: False

=== CROSS-PROVIDER PROOF COMPLETE ===
Dual registration succeeded. Ownership join via registry alone: NO.
```

---

## Step 4 — Findings (Q1–Q7 compressed)

Full write-up: [docs/SPIKE-FINDINGS-CROSS-PROVIDER.md](docs/SPIKE-FINDINGS-CROSS-PROVIDER.md)

1. **Far-end ownership in v1 declarations?** No first-class field. Only opaque Shapes/Metadata private convention (reject as design).
2. **Dual-register = join?** No. Two independent declarations; resolve is `(Provider, Type)` only.
3. **Where does join belong?** **Core** (or graph composition above providers), not the registry store. Matches three-way split.
4. **Closed-graph placeholders enough for estates?** Necessary, not sufficient. They close *one* provider’s graph; they do not name another PS.DrawIO provider/type/instance. Placeholder types are not even registry shape keys on PowerShell.
5. **Same as node/edge friction?** **New seam.** Kind-split ≠ ownership/join.
6. **Future design must answer:** edge-instance ownership fields; placeholder upgrade rules; cross-provider Id namespacing; type-level vs instance-level hints; whether placeholders become declared shapes; keep registry as store.
7. **Recommendation:** Do not claim estate diagrams from dual registration. Prefer Core-owned multi-graph join + explicit foreign refs on provider graphs. No registry join API in v1.x; no Metadata-as-secret-contract.

**Bottom line:** Registry v1 holds two providers. It cannot join their graphs.

---

## Items checklist (task 1–6)

1. [x] Read/quote CONTRACT + ConvertTo + DOMAIN-MODEL + PS manifest  
2. [x] Extend Terraform psd1 with cross-provider edge; stop on missing ownership field  
3. [x] Dual-register proof @ Registry v1.1.0 + PowerShell v1.0.0 content; raw transcript  
4. [x] `docs/SPIKE-FINDINGS-CROSS-PROVIDER.md`  
5. [x] No Registry / PowerShell / extraction / Core / commit  
6. [x] This results file updated  
