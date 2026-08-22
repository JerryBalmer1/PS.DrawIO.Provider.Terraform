# Cross-provider reference spike findings

**Repo:** `PS.DrawIO.Provider.Terraform` @ `b7031e4` (+ uncommitted spike edits)  
**Registry:** sibling checkout, tag `v1.1.0` (`e6c19e8`), `src/` matches tag (HEAD `ce38ef1`)  
**PowerShell provider:** sibling checkout, tag `v1.0.0` (`3c26691`), `src/` matches tag (HEAD `facb1ed`)  
**Scope:** declaration + registry dual-register only — can two providers' graphs be *joined* under Registry v1?  
**Date:** 2026-08-21  
**Proof:** `tools/Prove-CrossProviderSpike.ps1` → `tools/proof-cross-provider-transcript.txt`

Findings were written while authoring the edge declaration and running the dual-register proof, not after the fact.

---

## 1. What does each side already model for "outside my analysis unit"?

### PowerShell provider (quoted)

From `PS.DrawIO.Provider.PowerShell/docs/DOMAIN-MODEL.md`:

> External commands are represented by `PSExternalCommand` placeholder nodes, and unresolved invocations by `PSUnresolved` placeholder nodes, so every edge endpoint is present in `Nodes`.

> `Edges`: dependency records classified as `Internal`, `External`, or `Unresolved`. `From` and `To` always contain node `Id` values, never display names. … External edges also carry `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`.

From ADR 0001 (`docs/DECISIONS/0001-closed-graph.md`):

> Emit placeholder nodes for external and unresolved references. Edge endpoints always use node `Id` values. Placeholder nodes carry the reference name and classification… The decision is a reusable contract concern for future providers, not a PowerShell-only workaround.

From ADR 0002:

> Every external edge carries `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`.

**Declaration half gap:** the PowerShell *manifest* (`src/PS.DrawIO.Provider.PowerShell.psd1`) declares shape keys `PSFunction`, `PSClass`, `PSEnum`, `PSModule`, and edges `Internal` / `External` / `Unresolved` / `Inherits`. It does **not** declare `PSExternalCommand` or `PSUnresolved` as shape types. Placeholders are a **graph-schema** concern (DOMAIN-MODEL / ADR 0001), not registry shape keys. Proof confirmed: `PowerShell declares PSExternalCommand => False`, `PSUnresolved => False`.

### Terraform spike (this repo)

First spike declared in-domain nodes (`TfResource` … `TfProvider`) and in-domain edges (`ExplicitDependsOn`, `ImplicitReference`, `ModuleBoundary`, `ProviderAttachment`). Nothing modeled a far end owned by another PS.DrawIO provider.

This spike added one edge shape key only:

```powershell
CrossProviderReference = @{
    Edge  = $true
    Style = 'endArrow=open;dashed=1;dashPattern=2 2;'
}
```

No first-class ownership fields — see §2.

### Registry contract (quoted)

From `PS.DrawIO.Registry/docs/CONTRACT.md`:

> `Shapes` maps semantic type names to opaque declaration data; the registry stores it and never renders XML or performs layout.

> `Metadata` is an optional hashtable of opaque, provider-defined key/value data under `PrivateData.PSDrawIO` … The registry stores and returns it and never interprets it; beyond requiring a hashtable when present, contents are unvalidated.

> The registry returns declarations to Core. Providers never execute during shape resolution.

From `ConvertTo-PSDrawIODeclaration.ps1`, the stored declaration object is exactly:

| Field | Source |
|---|---|
| `ProviderName` | required |
| `ContractVersion` | required |
| `Capabilities` | required |
| `Shapes` | optional map (default `{}`) |
| `Metadata` | optional map (default `{}`) |

No `FarEndProvider`, `TargetType`, `Owner`, graph, or join field exists on the declaration.

From `REGISTRY.md` §4 resolution flow: Core calls `Resolve-PSDrawIOShape -Provider <name> -Type <type>` and gets back **one provider's** shape declaration. There is no multi-provider resolve.

Public surface at v1.1.0 (proof):  
`Get-PSDrawIOProvider`, `New-PSDrawIOProvider`, `Register-PSDrawIOProvider`, `Resolve-PSDrawIOShape`, `Test-PSDrawIOCapability`, `Test-PSDrawIOName`, `Test-PSDrawIOProviderConformance`, `Unregister-PSDrawIOProvider`.  
**Zero join / estate / graph APIs.**

---

## 2. Can a Terraform edge declaration name a far-end owner under v1 fields only?

**No — not as a first-class contract field.**

| Wanted field | In CONTRACT.md? | In ConvertTo-PSDrawIODeclaration? | Result |
|---|---|---|---|
| `FarEndProvider` / `TargetProvider` | No | No | Not a declaration field |
| `FarEndType` / `TargetType` | No | No | Not a declaration field |
| `Owner` on edge | No | No | Not a declaration field |
| Keys inside a `Shapes[...]` hashtable | Opaque blob | Copied as-is into `Shapes` | Round-trips if written; **never interpreted** |
| `Metadata` on `PSDrawIO` | Yes, opaque | Stored, unvalidated | Same private-convention cost as `Edge = $true` |

**What was tried:** authoring `CrossProviderReference` with comments for `FarEndProvider = 'PowerShell'` / `FarEndType = 'PSModule'`. Those keys were **not** written into the shipping spike shape (only `Edge` + `Style`) so the proof would not fake a contract that does not exist. Proof resolved the shape and listed keys: `Edge`, `Style` only. All ownership key probes returned `False`.

**If Metadata were used** (e.g. `Metadata = @{ CrossProviderHints = @{ CrossProviderReference = @{ FarEndProvider = 'PowerShell'; FarEndType = 'PSModule' } } }`):

- Registration would succeed (opaque hashtable).
- `Get-PSDrawIOProvider` would return it.
- **Costs (same class as `Edge = $true`):** unvalidated; Core must invent a private reader; second provider may invent a different schema; no conformance test; not in CONTRACT.md; becomes a de-facto contract without a major version.

**Stop condition hit:** the field is missing. Documented; did not invent a contract extension.

---

## 3. After dual-register, can registry cmdlets alone answer far-end ownership?

**No.**

Proof (`tools/Prove-CrossProviderSpike.ps1` against Registry `v1.1.0`):

1. Both manifests passed `Test-PSDrawIOProviderConformance`.
2. Dual `Register-PSDrawIOProvider -Force` succeeded: registered `PowerShell`, `Terraform`.
3. `Resolve-PSDrawIOShape -Provider Terraform -Type CrossProviderReference` returned `{ Edge = True; Style = ... }` — no owner.
4. `Resolve-PSDrawIOShape -Provider PowerShell -Type PSModule` works **only when the caller already knows** the far-end provider name and type.
5. `Resolve-PSDrawIOShape -Provider Terraform -Type PSModule` throws: *Provider 'Terraform' does not declare shape 'PSModule'.*
6. Join probe conclusion:  
   `Join method: none — registry has no join/ownership API`  
   `Join answer: UNANSWERABLE from registry cmdlets alone`

Dual registration is **not** the problem. Coexistence works. **Join is not a registry concern in v1.**

---

## 4. Answers to the seven spike questions

### Q1 — Is far-end ownership expressible in Registry v1 declarations?

**No** as a first-class field. Only via unvalidated private conventions inside opaque `Shapes` entries or `Metadata` (same cost class as `Edge = $true` from the first spike / Registry ADR 0002).

### Q2 — Does dual registration enable a registry-level join?

**No.** Dual registration stores two independent declarations. `Resolve-PSDrawIOShape` is keyed by `(Provider, Type)` only. Nothing links an edge type in provider A to a node type in provider B.

### Q3 — Where does join actually belong?

**Core (unbuilt), or a future graph-composition layer above providers — not the registry store.**

Evidence:

- `REGISTRY.md` three-way split: registry **stores + validates** declarations; Core **applies**.
- `CONTRACT.md`: registry returns declarations to Core; providers never execute during shape resolution.
- No public graph, edge-instance, or multi-provider resolve API exists at v1.1.0.
- PowerShell closed-graph placeholders are **per-provider graph schema** (DOMAIN-MODEL), not registry shape keys — even `PSExternalCommand` is absent from the PowerShell manifest.

A join needs instance-level node Ids and edge endpoints from two `*Graph` objects, plus a policy for when a Terraform placeholder should be replaced by a PowerShell analysis node. That is composition/rendering, not declaration storage.

### Q4 — Is PowerShell's closed-graph placeholder model enough for cross-provider estates?

**Necessary but not sufficient.**

- **Necessary:** every edge endpoint must resolve to a node Id inside *some* closed graph (ADR 0001). Without placeholders, single-provider graphs already break.
- **Not sufficient for multi-provider join:** placeholders say "outside this analysis unit," not "owned by provider PowerShell type PSModule instance X." `ExternalKind` (`BuiltIn` / `Module` / `Unknown`) is a PowerShell command taxonomy, not a PS.DrawIO provider pointer. Manifest does not even declare placeholder shape types for Core to style via `Resolve-PSDrawIOShape -Provider PowerShell -Type PSExternalCommand`.

### Q5 — Same friction as node/edge split, or a new seam?

**A new seam**, adjacent to the first.

| Seam | Defect | Workaround today |
|---|---|---|
| Node vs edge (spike 1) | One `Shapes` bucket for two kinds | `Edge = $true` private flag |
| Cross-provider ownership (spike 2) | No field and no API for "far end owned by provider X type Y" | None in registry; would need Metadata/shape side-channel **and** a Core join that does not exist |

Do **not** fold this into "add NodeTypes/EdgeTypes." Kind-split does not create ownership or join.

### Q6 — What must a future contract or Core design answer?

Minimum questions before multi-provider diagrams are honest:

1. **Ownership on edge instances (graph schema), not only declarations:** `ToProvider` / `ToType` / `ToId` (or equivalent) on the edge record after extraction.
2. **Placeholder upgrade rule:** when is a local `External`/`Unresolved`/foreign placeholder replaced by a node from another provider's graph?
3. **Id stability across providers:** how do Terraform addresses and PowerShell node Ids collide or namespace?
4. **Declaration vs instance:** which ownership facts are type-level (all `CrossProviderReference` edges go to PowerShell?) vs instance-level (this edge goes to module Foo)?
5. **If type-level hints exist in the contract:** first-class fields (major version) vs documented Metadata schema — do not leave a third silent `Edge = $true`-class convention.
6. **Registry role stays store/resolve-by-(provider,type):** join orchestration stays out of the registry kernel unless a deliberate ADR says otherwise.
7. **Placeholder shape registration:** should `PSExternalCommand` / provider-foreign stubs be real shape keys so Core can resolve styles without hardcoding?

### Q7 — Recommendation for estate diagrams

| Option | Verdict |
|---|---|
| A. Registry grows a join/ownership API in v1.x | **Reject for v1.** Violates three-way split; registry has no graphs. |
| B. Private Metadata / shape keys as de-facto join contract | **Reject as the design.** Acceptable only as a temporary spike note; same debt as `Edge = $true`. |
| C. Core owns multi-graph join; providers emit closed graphs with explicit foreign refs | **Prefer.** Matches REGISTRY.md. Requires graph schema work (not done) and likely a contract major if ownership becomes declarative. |
| D. Do not claim cross-provider estate diagrams until Core + graph schema exist | **Ship posture for now.** Dual-register is fine for shape resolution coexistence; it is not an estate join. |

**Bottom line:** Registry v1 can hold two providers. It cannot join their graphs. Cross-provider estate diagrams are a **Core + graph-schema** problem; treating dual registration as join would be a lie.

---

## 5. Manifest diff (this spike)

Added under `Shapes`:

- `CrossProviderReference` — `Edge = $true`, style only; comments document missing ownership fields.

Did **not** add:

- First-class contract fields
- `Metadata` join side-channel (documented as possible, not used)
- Extraction, HCL, Core, NodeTypes/EdgeTypes, Registry edits

---

## 6. Deliberately not built

- HCL / Terraform extraction
- Any graph object or JSON graph join
- Changes to `PS.DrawIO.Registry` or `PS.DrawIO.Provider.PowerShell`
- Contract version bump / NodeTypes / EdgeTypes
- Build, CI, SIGNOFF, commit, push
