# AGENT.md — LLM-oriented summary for WHOcares!

Purpose
- Provide a concise, machine-friendly summary of the WHOcares! flake-based workstation framework so an LLM or automation agent can understand and operate without reading every file.

Project at a glance
- Flake-powered framework (flake.nix + flake.lock). Home Manager profiles and optional NixOS hosts.
- Pinned inputs; reproducible dev shells, builds, and switches.
- Settings in settings.nix (checkout path, identity, targets).

Primary entrypoints & commands
- nix run .            -> prints targets/capabilities
- nix develop .        -> enter development shell (#aegis-dev)
- nix flake check      -> evaluate outputs and run quality gates
- nh home build . -c <target> / nh home switch . -c <target>
- Provided wrappers: hm, hm-check, nix-up, nix-audit, nix-fmt, nix-health

Important files & layout
- flake.nix, flake.lock: flake entry and pinned inputs
- settings.nix: local identity and checkout path
- lib/framework.nix: constructors and framework composition
- home/: Home Manager profiles and modules (llm-orchestrator.nix, zsh.nix, nvim.nix, etc.)
- hosts/: host scaffolds for NixOS outputs

LLM orchestration hooks
- home/modules/llm-orchestrator.nix exposes commands to build LLM-ready context bundles:
  - ctx, llm-copy, llm-open, llm-review, llm-patch, runlog
- Bundles and diagnostics are under: ~/.local/state/whocares/llm-orchestrator
- Bundles are redacted by default; always review before sending externally.

Developer checks & quality gates
- nix fmt, statix, deadnix, nix flake check --show-trace
- Dev shell: nix develop .#aegis-dev (includes nh, alejarandra, statix, deadnix)

How an LLM agent should act
1. Run `nix run .` to enumerate capabilities and targets.
2. Use `ctx --copy` or `llm-copy` to request a redacted context bundle before making suggestions or patches.
3. For code changes: create a branch, run quality gates (`nix flake check`, `nix fmt`, `statix`, `deadnix`), run `llm-review` to package changes for model review, then `llm-patch` to validate and apply patches.
4. Avoid sending secrets: the orchestrator redacts common tokens, but verify bundles first.

Quick automation checklist for agents
- Determine target (home config host) from settings.nix or `nix run .` output
- Use `nix develop` to get tooling
- Run linters/checks before proposing commits
- Use `llm-review`/`llm-patch` flow for AI-assisted patching

Contact / repository
- Origin: https://github.com/tarot-777/WHOcares-

Notes
- The repository expects to be used from its checkout path (/home/malachi/WHOcares!) or by setting AEGIS_FLAKE / WHOCARES_FLAKE environment variables.
- Treat the NixOS host outputs as scaffolds — do not reinstall hosts without adapting boot/filesystem settings.

--
This AGENT.md is intended for automation and agent use. If more detail is required for a specific task (build, switch, LLM bundle generation), request the exact command sequence and target.
