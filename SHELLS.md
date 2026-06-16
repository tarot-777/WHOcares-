# SHELLS.md — Termux / Kitty / Zsh aliases and functions

Purpose
- Explain the most-used aliases, wrappers, and functions present in WHOcares! so humans and agents can use shells (Termux/Kitty/Zsh) effectively.

Navigation & file helpers
- .., ..., .... — parent-directory shortcuts (1, 2, 3 levels)
- mkcd DIR — create DIR and cd into it
- cdf / z — change directory helpers (z uses frecency database)
- fm / fmh / fma — open file manager (Dolphin) or context-aware paths

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

Tips for agents and maintainers
- Use `ctx --copy` to get a redacted, ready-to-send context bundle before asking for repo changes.
- Run `nix develop` to get the dev tooling (nh, statix, deadnix) before performing actions that modify nix files.
- Always run the quality gates (`nix fmt`, `statix`, `deadnix`, `nix flake check`) before proposing commits or PRs.

Where to find the definitions
- Most aliases and functions are declared in Home Manager modules under `home/modules/*` and the shell module `home/modules/shell.nix` or `home/modules/zsh.nix`.

If you want, these explanations can be merged into AGENT.md or turned into in-repo manpages for each shell/tool.
