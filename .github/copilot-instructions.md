# Copilot instructions for WHOcares!

This file orients future Copilot/LLM sessions to the repository's workflows, checks, and structure.

---

## Build, test, and lint commands

- Enter the development toolchain (recommended first step):
  - nix develop .#aegis-dev

- Format / lint / quality gates (full-suite):
  - nix fmt
  - statix check .
  - deadnix .
  - shellcheck install.sh repair-from-documents-tree.sh
  - nix flake check --show-trace

- Run the Home Manager build/switch for a single profile:
  - nh home build . -c malachi@coffin
  - nh home switch . -c malachi@coffin
  - (alternatively: nix run .#home-build and nix run .#home-switch)

- Run a single check/tool on a specific file or path (examples):
  - statix check path/to/file.nix
  - deadnix path/to/file-or-dir
  - shellcheck path/to/script.sh
  - alejandra (nix fmt) on specific files via the dev shell: "whocares-fmt file.nix"

Notes: the `dev` shell includes nh, alejandra, statix, deadnix, shellcheck and ripgrep.

---

## High-level architecture (big picture)

- Flake-driven: flake.nix + flake.lock define inputs, outputs, apps, devShells, and checks.
- settings.nix: local identity, checkout path, supported systems, and default targets. Many commands and choices are derived from this file.
- lib/framework.nix: core constructors (mkHome, mkNixos, mkPkgs, overlays) used to assemble Home Manager profiles and NixOS host scaffolds.
- home/: Home Manager profiles and focused modules (zsh, shell, nvim, llm-orchestrator, media, etc.). Each module encapsulates a feature set and is intended to be reusable.
- hosts/: NixOS host scaffolds (scoped NixOS configuration that must be adapted before installing on hardware).
- shells/: developer/devshell definitions (aegis-dev) used by nix develop.
- Flake apps / commands: many user-facing actions are provided as small shell apps (info/home-build/home-switch/check/update) via the flake outputs.

This repo is a workstation framework: configuration modules are composable, pinned, and designed to be activated from the flake root.

---

## Key conventions and repository-specific patterns

- Identity/config separation: keep machine/user identity in settings.nix. Forks should update settings.nix to their checkout path and names.
- Modules-only pattern: Home Manager features belong under home/modules/*. NixOS-only configs belong under hosts/.
- No network fetch-on-activation: shell plugins and mutable dependencies must not be downloaded at activation time — Home Manager owns plugin sources.
- Quality gate required before changes: run `nix fmt`, `statix check`, `deadnix`, and `nix flake check` before proposing commits or PRs.
- Home Manager wrapper commands: prefer `nh` wrappers and provided `hm`, `hm-check`, `nix-fmt`, `nix-up`, `nix-audit`, and `nix-health` for short tasks.
- LLM orchestrator: use the llm toolchain exposed in home/modules/llm-orchestrator.nix:
  - Useful commands: ctx, llm-copy, llm-open, llm-review, llm-patch, runlog
  - Bundles and diagnostics are stored under: ~/.local/state/whocares/llm-orchestrator — bundles are redacted; review before sending outside the machine.
  - Agent flow (recommended): run `nix develop`, `ctx --copy` or `llm-copy` to get a redacted context bundle, run checks locally, and use `llm-review`/`llm-patch` when applying AI-generated patches.
- Path assumptions: repository commonly used from /home/malachi/WHOcares!; override with AEGIS_FLAKE or WHOCARES_FLAKE environment variables when running flake apps.
- Secrets & artifacts: do not add secrets, VM images, or machine-specific credentials to the repo. Privacy workflows intentionally require manual license acceptance and verification steps (Whonix flows).
- Command entrypoints are in the flake outputs: use `nix run .#<app>` or the provided wrappers created by the dev environment.

---

## Other in-repo assistant or rules files

Located and incorporated while writing these instructions:
- AGENT.md — concise, machine-friendly summary and an LLM-agent checklist (used as a primary source).
- SHELLS.md — shell aliases and wrapper guidance (used to capture common wrapper commands and agent tips).
- CONTRIBUTING.md — development and commit-check guidance.
- statix.toml — statix configuration and ignores.

No CLAUDE.md, .cursorrules, AGENTS.md, .windsurfrules, CONVENTIONS.md, or other assistant-specific rules files were found.

---

If changes are being made:
- Create a branch and run the full quality gate (`nix fmt`, `statix`, `deadnix`, `nix flake check`) before committing.

---

Created by Copilot CLI helper: this file summarizes build/test/lint commands, architecture, and conventions to help future Copilot sessions understand and act in this repository.

If you want any section expanded (examples for a specific module, more single-file command examples, or a short checklist for AI-assisted patches), say which area to expand.