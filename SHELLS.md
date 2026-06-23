# SHELLS.md — Kitty / Zsh / Nushell aliases and functions

Purpose
- Explain the aliases, wrappers, and shell functions present in WHOcares! so
  humans and agents can operate the workstation without reading every Home
  Manager module.

Activation basics
- `nix run .#home-build` builds the configured Home Manager profile.
- `nix run .#home-switch` activates the configured Home Manager profile.
- `hm-check` is the installed low-priority Home Manager build wrapper.
- `hm` is the installed low-priority Home Manager switch wrapper.
- `hmu` / `nix-safe-update` updates inputs, checks, builds, diffs, then
  switches only after the earlier stages pass.
- `exec zsh` reloads the active shell after activation.

Framework target selection
- `WHOCARES_FLAKE` / `AEGIS_FLAKE` overrides the checkout or flake ref.
- `WHOCARES_HOST` / `AEGIS_HOST` selects the Home Manager host suffix.
- `WHOCARES_PROFILE` / `AEGIS_PROFILE` selects the full Home Manager profile.
- `WHOCARES_NIXOS_HOST` / `AEGIS_NIXOS_HOST` selects the NixOS output.
- `WHOCARES_NIX_JOBS`, `WHOCARES_NIX_CORES`, and `WHOCARES_NICE` tune wrapper
  resource usage.

Navigation & file helpers
- .., ..., .... — parent-directory shortcuts (1, 2, 3 levels)
- mkcd DIR — create DIR and cd into it
- cdf / z — change directory helpers (z uses frecency database)
- fm / fmh / fma — open file manager (Dolphin) or context-aware paths
- dots / cfg — jump to the configured WHOcares! flake
- root / whocares-cd — jump to the nearest flake root
- edit / whocares-edit — open the nearest flake root in `$EDITOR`

Git helpers
- g, gs, ga, gaa, gc, gco — wrappers for git; e.g. `gs` = `git status`, `gco` = `git checkout`
- gl, gp, gpl — log, push, pull wrappers
- lg — pretty log with graph
- git-root — print repository root

Nix & framework helpers
- nd, nfl, nr, ns, nfc, ndev, nshow — nearest-flake and nix helpers
- hm, hm-check — Home Manager switch and low-priority check wrappers
- nix-up — update flake inputs (flake.lock)
- nix-fmt — format Nix files with alejandra
- nix-audit, nix-health — auditing and health checks
- nix-target / target — print the selected NixOS flake target
- osb / nixos-build — build the selected NixOS host
- ost / nixos-test — test the selected NixOS host with sudo
- osboot / nixos-boot — build and select the next-boot generation
- oss / os / whocares — switch the selected NixOS host
- osdry / nixos-dry — dry-build the selected NixOS host
- osvm / nixos-vm — build the selected NixOS VM
- installos / whocares-install — guarded nixos-anywhere install wrapper
- targets / whocares-targets — show supported Home Manager and NixOS targets
- nfind — search nixpkgs and nix-locate together
- nopt — search NixOS and Home Manager options
- nlock — browse `flake.lock`
- ndix — derivation diff helper
- nreview — local nixpkgs PR review helper

Shell plugin commands
- zpl — list pinned Zsh plugin names and versions
- zpr — reload Zsh configuration
- zpu — update flake inputs, then run hm (update+switch helper)

LLM orchestration commands (see llm-orchestrator)
- ctx — print a redacted Markdown context bundle for the current repo
- ctx --copy --open chatgpt — copy context and open ChatGPT
- llm-copy — copy stdin/files/directory context as an LLM-ready prompt
- llm-open <engine> FILE — open a prompt in a particular LLM service
- runlog CMD... — run a command and save a transcript for review
- llm-review, llm-patch — package and apply AI-produced patches safely

Whonix helpers (VM management)
- wx, wxs, wxd, wxsetup, wxverify, wxextract, wximport — manage Whonix VM lifecycle, verify signatures, extract, and import official images

Kitty / terminal helpers
- ka — open framework root in Kitty
- kdev — open a tab running `nix develop`
- kcheck — open a tab running the Home Manager build
- kswitch — open a tab running the Home Manager switch
- kdash — open the WHOcares terminal dashboard
- ktmux / ktops — open tmux main or ops sessions
- icat, kdiff, khints, kclip, kgrep, kssh, ktheme, kunicode, ktransfer,
  kkeys — Kitty kitten helpers

Tips for agents and maintainers
- Use `ctx --copy` to get a redacted, ready-to-send context bundle before asking for repo changes.
- Run `nix develop` to get the dev tooling (nh, statix, deadnix) before performing actions that modify nix files.
- Always run the quality gates (`nix fmt`, `nix flake check --no-build
  --show-trace`, `nix build .#checks.x86_64-linux.source-quality --no-link`)
  before proposing commits or PRs.
- For activation changes, run `nix run .#home-build` before
  `nix run .#home-switch`.
- For NixOS installs, do not run `nixos-install` or `whocares-install` until
  `hosts/<host>/hardware-configuration.nix` and `hosts/<host>/disko.nix` have
  been reviewed for that machine.

Where to find the definitions
- Most aliases and functions are declared in Home Manager modules under `home/modules/*` and the shell module `home/modules/shell.nix` or `home/modules/zsh.nix`.
- Generated local references are installed under `~/.local/share/aegis/`.
