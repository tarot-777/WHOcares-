# AGENT.md — LLM-oriented summary for WHOcares!

Purpose
- Provide a concise, machine-friendly summary of the WHOcares! flake-based workstation framework so an LLM or automation agent can understand and operate without reading every file.

Project at a glance
- Flake-powered framework (flake.nix + flake.lock). Home Manager profiles and optional NixOS hosts.
- Pinned inputs; reproducible dev shells, builds, and switches.
- Settings in settings.nix (checkout path, identity, targets).
- Current local checkout: `/home/malachi/WHOcares!`.
- Current default Home Manager profile from settings: `malachi@coffin`.

Primary entrypoints & commands
- nix run .            -> prints targets/capabilities
- nix develop .        -> enter development shell (#aegis-dev)
- nix flake check      -> evaluate outputs and run quality gates
- ./install.sh         -> generate machine-local settings.nix for deployment
- nix run .#home-build / nix run .#home-switch
- nix run .#nixos-install -- <host> <ssh-target>
- Provided wrappers: hm, hm-check, nix-up, nix-audit, nix-fmt, nix-health

Deployment runbook
1. Inspect targets with `nix run .#info`.
2. On a new machine, run `./install.sh --home-host workstation` or choose `laptop` / `hp-laptop`.
3. Build before activating: `nix run .#home-build`.
4. Activate Home Manager only when requested: `nix run .#home-switch`.
5. For existing NixOS, add/review `hosts/<host>/hardware-configuration.nix`, build the host, then use `nix run .#nixos-switch`.
6. For fresh NixOS, require explicit `hosts/<host>/disko.nix`, then run `nix run .#nixos-install -- <host> root@<target-ip>`.

Runtime overrides
- WHOCARES_FLAKE / AEGIS_FLAKE: checkout path or flake ref.
- WHOCARES_HOST / AEGIS_HOST: Home Manager host suffix.
- WHOCARES_PROFILE / AEGIS_PROFILE: full Home Manager profile.
- WHOCARES_NIXOS_HOST / AEGIS_NIXOS_HOST: NixOS host output.
- WHOCARES_NIX_JOBS, WHOCARES_NIX_CORES, WHOCARES_NICE: resource limits.

Important files & layout
- flake.nix, flake.lock: flake entry and pinned inputs
- settings.nix: local identity and checkout path
- lib/framework.nix: constructors and framework composition
- home/: Home Manager profiles and modules (llm-orchestrator.nix, zsh.nix, nvim.nix, etc.)
- hosts/: host scaffolds for NixOS outputs
- install.sh: portable bootstrap and settings.nix generator.
- README.md: complete human deployment and operations guide.
- HOWTOnotCRY.md: narrative architecture and survival reference.
- SHELLS.md: command and alias reference.
- CONTRIBUTING.md: change hygiene and validation contract.

LLM orchestration hooks
- home/modules/llm-orchestrator.nix exposes commands to build LLM-ready context bundles:
  - ctx, llm-copy, llm-open, llm-review, llm-patch, runlog
- Bundles and diagnostics are under: ~/.local/state/whocares/llm-orchestrator
- Bundles are redacted by default; always review before sending externally.

Developer checks & quality gates
- nix fmt
- nix flake check --no-build --show-trace
- nix build .#checks.x86_64-linux.source-quality --no-link
- nix run .#home-build
- Dev shell: nix develop .#aegis-dev (includes nh, alejandra, statix, deadnix)

How an LLM agent should act
1. Run `nix run .` to enumerate capabilities and targets.
2. Use `ctx --copy` or `llm-copy` to request a redacted context bundle before making suggestions or patches.
3. For code changes: run quality gates (`nix fmt`, `nix flake check --no-build --show-trace`, source-quality build), run `llm-review` to package changes for model review, then `llm-patch` to validate and apply patches when using AI-generated patches.
4. Avoid sending secrets: the orchestrator redacts common tokens, but verify bundles first.
5. Never run fresh NixOS deployment without explicit user request and reviewed `disko.nix`.
6. Do not revert user changes in the working tree unless explicitly asked.

Quick automation checklist for agents
- Determine target (home config host) from settings.nix or `nix run .` output
- Use `nix develop` to get tooling
- Run linters/checks before proposing commits
- Use `llm-review`/`llm-patch` flow for AI-assisted patching
- If Home Manager activation reports Plasma wallpaper errors on a non-Plasma or Niri session, treat them as non-fatal.
- If a Nix command cannot access `/nix/var/nix/daemon-socket/socket` inside a sandbox, rerun outside the sandbox with user approval.

Contact / repository
- Origin: https://github.com/tarot-777/WHOcares-

Notes
- Fresh machines should run `./install.sh` first; runtime commands can also use AEGIS_FLAKE / WHOCARES_FLAKE environment overrides.
- Treat the NixOS host outputs as scaffolds — do not reinstall hosts without adapting boot/filesystem settings.

--
This AGENT.md is intended for automation and agent use. If more detail is required for a specific task (build, switch, LLM bundle generation), request the exact command sequence and target.
