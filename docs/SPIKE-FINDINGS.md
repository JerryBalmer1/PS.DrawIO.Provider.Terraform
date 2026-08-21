# Terraform contract spike findings

**Repo:** `PS.DrawIO.Provider.Terraform` @ `dd5b7d7`  
**Registry:** sibling checkout, tag `v1.0.0` (`8e96f4d`), `src/` matches tag  
**Scope:** declaration half only — answer whether Registry v1's single `Shapes` collection is a Terraform problem too  
**Date:** 2026-08-21

Findings were written while authoring the manifest and running the proof, not after the fact.

---

## 1. What node types and edge types does Terraform need?

### Node types (identity + source + layout)

| Type | What it is | Properties it needs |
|---|---|---|
| `TfResource` | Managed or data resource (`aws_instance`, `aws_s3_bucket`, `random_id`, …). Concrete type string is instance data, not a separate shape per cloud type. | `Variants` (`Managed`/`Data`), `Style`, `LinkTemplate` (`vscode://file/{path}:{line}`), `LayoutHints` (Group=`Resources`) |
| `TfModule` | Module block — root or child call | `Variants` (`Root`/`Child`), `Style`, `LinkTemplate`, `LayoutHints` (Group=`Modules`) |
| `TfVariable` | Input variable | `Style`, `LinkTemplate`, `LayoutHints` (Group=`Inputs`) |
| `TfOutput` | Output value | `Style`, `LinkTemplate`, `LayoutHints` (Group=`Outputs`) |
| `TfLocal` | Local value | `Style`, `LinkTemplate`, `LayoutHints` (Group=`Locals`) |
| `TfProvider` | Provider configuration / alias (not a cloud resource) | `Style`, `LinkTemplate`, `LayoutHints` (Group=`Providers`) |

Concrete example: an `aws_instance` is a `TfResource` node with variant `Managed`. It needs a stable id (address), optional source link into the `.tf` file, and a layout group so Core can stack resources. It does **not** need edge-only fields.

### Edge types (relationship only)

| Type | What it is | Properties it needs |
|---|---|---|
| `ExplicitDependsOn` | `depends_on` meta-argument | Relationship style; source/target addresses at graph time. No `LinkTemplate`, no `LayoutHints` group |
| `ImplicitReference` | Interpolation / reference (`var.x`, `module.a.out`, `aws_vpc.main.id`) | Dashed/open arrow style; majority of real graphs |
| `ModuleBoundary` | Value crossing a module block (root→child input, child output→sibling, etc.) | Distinct style from plain implicit refs so Core can emphasize module I/O |
| `ProviderAttachment` | Resource/module → provider config, including `providers = {}` passthrough | Distinct style; often invisible in naive graphs |

Concrete example: an implicit dependency edge from `aws_instance.app` to `aws_subnet.private` needs source address, target address, and edge semantics. It does **not** need `Variants`, `LayoutHints.Group`, or a `vscode://` link template on the edge type itself (source extent may live on the graph edge instance later — that is extraction, not declaration).

Out of spike scope but noted: `count`/`for_each` multiplicity is instance data on a node, not a separate shape type. `moved` / lifecycle are also not declaration types for v1-shaped diagrams.

---

## 2. Did merging them into one `Shapes` collection cause friction?

**Yes.**

Concrete moment: while writing `src/PS.DrawIO.Provider.Terraform.psd1`, after the six node entries (`TfResource` … `TfProvider`) each carrying `Style` / `LinkTemplate` / `LayoutHints`, the next keys were edge types. The contract only offers `Shapes`. There is no `NodeTypes` or `EdgeTypes` field.

The line that bit:

```powershell
ExplicitDependsOn = @{
    Edge  = $true   # ad-hoc flag — not in CONTRACT.md
    Style = 'endArrow=block;dashed=0;'
}
```

Without some private discriminator, a consumer of `Resolve-PSDrawIOShape` cannot tell whether the returned hashtable is a node declaration or an edge declaration. Registry validation only checks that each shape entry is non-null (`ConvertTo-PSDrawIODeclaration`); it does not know or care about `Edge`.

I wanted to write `NodeTypes` / `EdgeTypes`. Per spike rules I stopped. That wanting is the finding.

---

## 3. Same friction as PowerShell, or different?

**Same friction.** Matches and slightly extends Provider.PowerShell.

Quoted from `PS.DrawIO.Provider.PowerShell/docs/PATTERNS.md`:

> The provider exposed a concrete contract limitation: node types and edge types have different properties, different validation needs, and different rendering paths, but Registry v1 models both as entries in one opaque `Shapes` collection. The resulting acceptance finding is not missing provider work; adding `NodeTypes` and `EdgeTypes` locally would duplicate declarations and create a second source of truth beside `Shapes`.

And ADR 0003:

> They are not interchangeable: nodes carry identity, variants, source links, and layout hints; edges carry relationship semantics, aggregation, and external classification.

**Match:** Terraform nodes want identity/variants/links/hints; edges want relationship style only. One opaque map forces a side-channel (`Edge = $true`) identical in spirit to PowerShell's `Internal`/`External`/`Unresolved`/`Inherits` entries.

**Extend (Terraform-specific texture, not a different defect):**

- Terraform edges are more visually distinct from nodes than PowerShell's call/inherit edges (dashed reference vs solid depends_on vs module boundary). That makes the missing kind-split more painful for a future Core renderer, but the contract defect is still "one bucket for two kinds."
- Resource *type strings* (`aws_instance`) are instance data, not shape keys — so Terraform did **not** need hundreds of shape entries. The friction is node-vs-edge, not cardinality of resource types.

**Does not contradict** PATTERNS.md. Second data point confirms ADR 0003's hypothesis: this is not a PowerShell-shaped coincidence.

---

## 4. What else in the v1 contract was awkward for Terraform?

| Area | Observation |
|---|---|
| **Layout hints** | `Group` + `Direction` were enough. No urge to put geometry in the provider. Boundary held. |
| **Link templates** | `vscode://file/{path}:{line}` works for `.tf` the same as `.ps1`. No friction. |
| **Capabilities** | `Shapes` / `Links` / `LayoutHints` fit. Did not declare `Analysis` (no extraction half). Capability check correctly returned `$false` for `Analysis`. |
| **Provider naming** | `Terraform` is valid PascalCase, no dots. Fine. |
| **No shape kind in schema** | Already covered in §2–3. Registry stores opaque maps; Core must invent or inherit a convention to separate nodes from edges. |
| **No required shape keys** | Contract does not require `Style` or anything else inside a shape entry. Good for edges (minimal), weak for nodes (nothing ensures a node has a style). Not Terraform-specific. |
| **Module as both node and boundary** | `TfModule` is a node; `ModuleBoundary` is an edge. Easy to model as two shape keys — but again only if you accept both kinds in one map. |
| **Cloud provider vs PS.DrawIO provider** | Naming collision in the domain ("provider" means two things). Not a registry bug; document carefully. `TfProvider` is the Terraform provider-config node. |

Nothing here was as sharp as the node/edge merge. Secondary notes only.

---

## 5. What was easy?

- Manifest-only provider: `Import-PowerShellDataFile` + `PrivateData.PSDrawIO` is enough to register. No module body required for the declaration half.
- `Test-PSDrawIOProviderConformance` against Registry `v1.0.0`: 4/4 green with zero custom conformance code in this repo.
- `Register-PSDrawIOProvider` → `Resolve-PSDrawIOShape` for both a node (`TfResource`) and an edge (`ImplicitReference`) worked on first try once the manifest parsed.
- `Test-PSDrawIOCapability` behaved correctly for declared and undeclared capabilities.
- Variants (`Managed`/`Data`, `Root`/`Child`) mapped cleanly — same pattern as PowerShell Public/Private.
- Hints-never-geometry held; no temptation to encode x/y.
- Collapsing all cloud resource types into one `TfResource` shape avoided an explosion of keys and felt natural.

Baseline: the registry as a **store and resolve** broker is pleasant. The pain is almost entirely the single `Shapes` taxonomy.

---

## 6. Recommendation

**Registry v1's `Shapes` model should change, but not in this spike and not by provider-local forks.** Two providers (PowerShell, Terraform) now hit the same defect: nodes and edges are different declaration kinds forced into one opaque map, papered over with an unvalidated `Edge = $true` (or equivalent) convention. Minimum contract change for a future major: split `Shapes` into `NodeTypes` and `EdgeTypes` (or add a required kind discriminator the registry validates), keep entries opaque otherwise, and leave layout/XML in Core. Until that major, keep v1 as-is, do **not** add parallel `NodeTypes`/`EdgeTypes` beside `Shapes` in either provider (duplication / second source of truth — ADR 0003 option 2), and treat the PowerShell failing acceptance test plus this spike as the evidence pack. **Do not generalize further from one provider; this is the second data point ADR 0003 asked for.**

---

## Proof summary

| Step | Result |
|---|---|
| Import Registry @ v1.0.0 content | OK (`ModuleVersion` 1.0.0; `src/` matches tag) |
| `Test-PSDrawIOProviderConformance` | `$true` (4 passed, 0 failed) |
| `Register-PSDrawIOProvider` | ProviderName=`Terraform`, 10 shape keys |
| `Resolve-PSDrawIOShape -Type TfResource` | Style, LinkTemplate, Variants, LayoutHints |
| `Resolve-PSDrawIOShape -Type ImplicitReference` | Edge=`True`, Style |
| `Test-PSDrawIOCapability` | Shapes/Links/LayoutHints `$true`; Analysis `$false` |
