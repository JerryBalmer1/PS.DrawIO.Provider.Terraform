@{
    # Spike-only declaration half. No RootModule / exports — not a shipping provider.
    ModuleVersion = '0.0.0'
    GUID = 'a7c4e2b1-9f3d-4e8a-b6c1-5d2f0a8e9173'
    Author = 'Jerry Balmer'
    Description = 'Throwaway contract spike: Terraform shapes against Registry v1 Shapes collection.'
    PowerShellVersion = '7.0'
    PrivateData = @{
        PSData = @{
            Tags = @('PSDrawIO', 'Provider', 'Terraform', 'Spike')
        }
        PSDrawIO = @{
            ContractVersion = 1
            ProviderName    = 'Terraform'
            Capabilities    = @('Shapes', 'Links', 'LayoutHints')
            # FINDING (written while authoring): node types want Style/LinkTemplate/
            # LayoutHints/Variants; edge types want relationship semantics only.
            # Registry v1 has one bucket — Shapes — so both land here, distinguished
            # only by an ad-hoc Edge = $true flag (same workaround PowerShell used).
            # Wanted NodeTypes/EdgeTypes; stopped. That wanting is the finding.
            Shapes = @{
                # --- node types (identity + source + layout) ---
                TfResource = @{
                    # aws_instance, aws_s3_bucket, random_id, … — type label is runtime data
                    Variants     = @('Managed', 'Data')
                    Style        = 'rounded=0;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Resources'; Direction = 'Vertical' }
                }
                TfModule = @{
                    Variants     = @('Root', 'Child')
                    Style        = 'shape=module;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Modules'; Direction = 'Vertical' }
                }
                TfVariable = @{
                    Style        = 'ellipse;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Inputs'; Direction = 'Vertical' }
                }
                TfOutput = @{
                    Style        = 'ellipse;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Outputs'; Direction = 'Vertical' }
                }
                TfLocal = @{
                    Style        = 'ellipse;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Locals'; Direction = 'Vertical' }
                }
                TfProvider = @{
                    # provider "aws" / aliased providers — config node, not a cloud resource
                    Style        = 'shape=hexagon;perimeter=hexagonPerimeter;whiteSpace=wrap;html=1;'
                    LinkTemplate = 'vscode://file/{path}:{line}'
                    LayoutHints  = @{ Group = 'Providers'; Direction = 'Vertical' }
                }

                # --- edge types (relationship only; no layout group, no source link) ---
                # FINDING: writing these next to TfResource forced a private convention
                # (Edge = $true) the contract neither defines nor validates. Without it,
                # Core cannot tell a node declaration from an edge declaration.
                ExplicitDependsOn = @{
                    Edge  = $true
                    Style = 'endArrow=block;dashed=0;'
                    # carries: source address, target address; no LinkTemplate/LayoutHints
                }
                ImplicitReference = @{
                    Edge  = $true
                    Style = 'endArrow=open;dashed=1;'
                    # interpolation / reference edge; often the majority of the graph
                }
                ModuleBoundary = @{
                    Edge  = $true
                    Style = 'endArrow=block;dashed=1;dashPattern=1 3;'
                    # root→child or sibling module I/O crossing a module block
                }
                ProviderAttachment = @{
                    Edge  = $true
                    Style = 'endArrow=open;dashed=1;dashPattern=8 4;'
                    # resource/module → provider config (incl. providers = {} passthrough)
                }

                # --- cross-provider edge (spike 2: join ownership probe) ---
                # FINDING: wanted first-class FarEndProvider / TargetType / Owner fields
                # so an edge could say "far end is PowerShell:PSModule". CONTRACT.md and
                # ConvertTo-PSDrawIODeclaration store only ContractVersion, ProviderName,
                # Capabilities, Shapes, Metadata — none of those ownership keys exist.
                # Stopped inventing contract fields. Private Metadata / shape-key side
                # channels are documented in docs/SPIKE-FINDINGS-CROSS-PROVIDER.md.
                CrossProviderReference = @{
                    Edge  = $true
                    Style = 'endArrow=open;dashed=1;dashPattern=2 2;'
                    # Attempted (not contract fields — private convention only, like Edge):
                    # FarEndProvider = 'PowerShell'
                    # FarEndType     = 'PSModule'
                    # Those keys would round-trip inside the opaque shape hashtable if
                    # written, but Resolve-PSDrawIOShape never interprets them and no
                    # registry cmdlet joins them to another provider's declaration.
                }
            }
            # Optional Metadata is opaque (CONTRACT.md). Could stash join hints here
            # (e.g. CrossProviderHints) — same unvalidated private-convention cost as
            # Edge = $true. Not used as a substitute for a real ownership field.
        }
    }
}
