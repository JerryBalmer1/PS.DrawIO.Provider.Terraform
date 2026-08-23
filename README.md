# PS.DrawIO.Provider.Terraform

## Agent execution protocol

Agent work follows [`.agent/TRAPS.md`](.agent/TRAPS.md): accumulated failure knowledge read once before any task. Per-run plans and attempt logs go in `.agent/EXECUTION.md` (gitignored). See [`.agent/README.md`](.agent/README.md).

## Development

Run `git config core.hooksPath .githooks` after cloning to enable the commit-msg hook.
