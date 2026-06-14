# ---------------------------------------------------------------------------
# awesome-tools.nix — Curated toolchain from Awesome lists
#
# Kitty terminal theming lives in ./kitty.nix (Catppuccin + power-user defaults).
#
# Sources mapped to nixpkgs:
#   • awesome-nix              — CLI, Development, Virtualisation
#   • awesome-linux-containers — podman, distrobox, sandboxes
#   • awesome-cli-apps         — modern terminal replacements
#   • awesome-security         — recon helpers (complements home.nix)
#
# Target: bare-metal Arch + Niri + standalone Home Manager (not NixOS)
# ---------------------------------------------------------------------------
{
  flakeRoot ? "/home/malachi/WHOcares!",
  hostName ? "coffin",
  lib,
  nixosHostName ? "Aegis-Dualis",
  pkgs,
  userName ? "malachi",
  ...
}: let
  nixIndex = "${pkgs.nix-index}/bin/nix-index";
  nixLocate = "${pkgs.nix-index}/bin/nix-locate";
  jq = "${pkgs.jq}/bin/jq";

  # `, foo` — comma + nix-index: run a binary without installing it
  commaRun = pkgs.writeShellScriptBin "nix-comma" ''
    exec ${pkgs.comma}/bin/comma "$@"
  '';

  # Fuzzy search nixpkgs + show whether already in HM generation
  nixPkgFind = pkgs.writeShellScriptBin "nix-pkg-find" ''
    set -euo pipefail
    term="''${1:?Usage: nix-pkg-find <name>}"
    echo "[*] nix search (top 15)..."
    nix search nixpkgs "$term" --json 2>/dev/null \
      | ${jq} -r 'to_entries[:15][] | "\(.key | split(".") | last)\t\(.value.version // "?")\t\(.value.description // "" | .[0:80])"' \
      | column -t -s $'\t' 2>/dev/null || nix search nixpkgs "$term" 2>/dev/null | head -20
    echo ""
    echo "[*] nix-locate (which package owns a binary named like '$term')..."
    ${nixLocate} -w "$term" 2>/dev/null | head -10 || echo "  (no nix-index hit — run: nix-index)"
  '';

  # Visual store usage — awesome-nix: nix-du
  nixStoreDu = pkgs.writeShellScriptBin "nix-store-du" ''
    exec ${pkgs.nix-du}/bin/nix-du "$@"
  '';

  # Ranger-like flake.lock browser — awesome-nix: nix-melt
  nixLockMelt = pkgs.writeShellScriptBin "nix-lock" ''
    exec ${pkgs.nix-melt}/bin/nix-melt "$@"
  '';

  # Fast derivation diff — awesome-nix: dix
  nixDix = pkgs.writeShellScriptBin "nix-dix" ''
    exec ${pkgs.dix}/bin/dix "$@"
  '';

  # Update a single package expression — awesome-nix: nix-update
  nixPkgUpdate = pkgs.writeShellScriptBin "nix-pkg-update" ''
    exec ${pkgs.nix-update}/bin/nix-update "$@"
  '';

  # Scaffold fetcher from URL — awesome-nix: nurl
  nixNurl = pkgs.writeShellScriptBin "nix-nurl" ''
    exec ${pkgs.nurl}/bin/nurl "$@"
  '';

  # HM/NixOS option TUI search — awesome-nix: optnix
  nixOptSearch = pkgs.writeShellScriptBin "nix-opt" ''
    exec ${pkgs.optnix}/bin/optnix "$@"
  '';

  hmSwitch = pkgs.writeShellScriptBin "hm" ''
    set -euo pipefail
    flake="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${flakeRoot}}}"
    host="''${WHOCARES_HOST:-''${AEGIS_HOST:-${hostName}}}"
    profile="''${WHOCARES_PROFILE:-''${AEGIS_PROFILE:-${userName}@''${host}}}"
    jobs="''${WHOCARES_NIX_JOBS:-1}"
    cores="''${WHOCARES_NIX_CORES:-2}"
    exec ${pkgs.coreutils}/bin/nice -n "''${WHOCARES_NICE:-10}" \
      ${pkgs.util-linux}/bin/ionice -c2 -n7 \
      ${pkgs.nh}/bin/nh home switch "$flake" \
      --configuration "$profile" \
      --max-jobs "$jobs" \
      --cores "$cores" \
      "$@"
  '';

  hmCheck = pkgs.writeShellScriptBin "hm-check" ''
    set -euo pipefail
    flake="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${flakeRoot}}}"
    host="''${WHOCARES_HOST:-''${AEGIS_HOST:-${hostName}}}"
    profile="''${WHOCARES_PROFILE:-''${AEGIS_PROFILE:-${userName}@''${host}}}"
    exec ${pkgs.coreutils}/bin/nice -n "''${WHOCARES_NICE:-10}" \
      ${pkgs.util-linux}/bin/ionice -c2 -n7 \
      ${pkgs.nh}/bin/nh home build "$flake" \
      --configuration "$profile" \
      --max-jobs "''${WHOCARES_NIX_JOBS:-1}" \
      --cores "''${WHOCARES_NIX_CORES:-2}" \
      "$@"
  '';

  nixAudit = pkgs.writeShellScriptBin "nix-audit" ''
    set -euo pipefail
    root="''${1:-''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-$PWD}}}"
    ${pkgs.deadnix}/bin/deadnix "$root"
    ${pkgs.statix}/bin/statix check "$root"
  '';

  nixFmt = pkgs.writeShellScriptBin "nix-fmt" ''
    set -euo pipefail
    root="''${1:-''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-$PWD}}}"
    exec ${pkgs.alejandra}/bin/alejandra "$root"
  '';

  nixGc = pkgs.writeShellScriptBin "nix-gc" ''
    exec ${pkgs.nix}/bin/nix-collect-garbage -d "$@"
  '';

  nixUp = pkgs.writeShellScriptBin "nix-up" ''
    set -euo pipefail
    flake="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${flakeRoot}}}"
    exec ${pkgs.nix}/bin/nix flake update --flake "path:''${flake}" "$@"
  '';

  nixHealth = pkgs.writeShellScriptBin "nix-health" ''
    set -euo pipefail
    echo "[*] nix version"
    ${pkgs.nix}/bin/nix --version
    echo "[*] flake outputs"
    ${pkgs.nix}/bin/nix flake show "path:''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${flakeRoot}}}" --all-systems
    echo "[*] home-manager build"
    hm-check
  '';

  whocaresSwitch = pkgs.writeShellScriptBin "whocares" ''
    set -euo pipefail
    flake="''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-${flakeRoot}}}"
    host="''${WHOCARES_NIXOS_HOST:-''${AEGIS_NIXOS_HOST:-${nixosHostName}}}"
    exec sudo ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "path:''${flake}#''${host}" "$@"
  '';

  aegisSwitch = pkgs.writeShellScriptBin "aegis" ''
    exec ${whocaresSwitch}/bin/whocares "$@"
  '';

  # Review a nixpkgs PR locally — awesome-nix: nixpkgs-review
  nixReviewPr = pkgs.writeShellScriptBin "nix-review" ''
    exec ${pkgs.nixpkgs-review}/bin/nixpkgs-review "$@"
  '';

  # Declarative ephemeral NixOS VM — awesome-nix: nixos-shell
  nixVmShell = pkgs.writeShellScriptBin "nix-vm" ''
    exec ${pkgs.nixos-shell}/bin/nixos-shell "$@"
  '';

  # One-shot NixOS containers — awesome-nix: extra-container
  nixExtraCtr = pkgs.writeShellScriptBin "nix-ctr" ''
    exec ${pkgs.extra-container}/bin/extra-container "$@"
  '';

  # docker-compose via Nix — awesome-nix: arion
  nixCompose = pkgs.writeShellScriptBin "nix-compose" ''
    exec ${pkgs.arion}/bin/arion "$@"
  '';

  # Cheatsheet lookup — awesome-cli-apps
  cheatSheet = pkgs.writeShellScriptBin "cs" ''
    exec ${pkgs.tealdeer}/bin/tldr "$@"
  '';

  # Verify awesome-list tools are on PATH after `hm`
  toolsCheck = pkgs.writeShellScriptBin "tools-check" ''
    set -uo pipefail
    ok=0 miss=0

    check() {
      if command -v "$1" &>/dev/null; then
        printf "  ✓ %-22s %s\n" "$1" "$(command -v "$1")"
        ok=$((ok + 1))
      else
        printf "  ✗ %-22s not found\n" "$1"
        miss=$((miss + 1))
      fi
    }

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  tools-check — Awesome-list toolchain status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "── Nix quality (health.nix + awesome-tools.nix) ──"
    for t in hm hm-check nix-health nix-audit nix-fmt nh alejandra statix deadnix \
             nixd nil nix-tree nvd nom manix comma nix-search-tv cachix devenv \
             nix-index nix-locate nix-du nix-melt dix nix-update nurl optnix angrr \
             nix-output-monitor nix-diff nix-init vulnix nix-fast-build colmena deploy-rs \
             nix-pkg-find nix-store-du nix-lock nix-dix nix-review nix-vm nix-ctr; do
      check "$t"
    done
    echo ""
    echo "── Arch hybrid (non-NixOS helpers) ────────────────"
    for t in nix-ld topgrade; do
      check "$t"
    done
    echo ""
    echo "── Modern CLI ─────────────────────────────────────"
    for t in eza bat fd rg fzf zoxide delta glow difft cheat navi \
             btm gdu broot watchexec distrobox lazydocker tldr television ast-grep \
             atac posting oha trip zellij just fq gum pueue mprocs sad jqp viddy \
             entr csvlens; do
      check "$t"
    done
    echo ""
    echo "── Niri + DMS session ─────────────────────────────"
    for t in niri dms fuzzel wl-copy cliphist grim slurp; do
      check "$t"
    done
    echo ""
    if [[ $miss -eq 0 ]]; then
      echo "  ✅ All checked tools present ($ok)"
    else
      echo "  ⚠️  $miss missing — run: hm && arch-deps"
    fi
    echo ""
  '';

  awesomeList = pkgs.writeShellScriptBin "awesome-list" ''
    set -euo pipefail
    cat <<'EOF'
    Aegis-Dualis · installed Awesome-list toolchain
    ═══════════════════════════════════════════════

    Nix quality (awesome-nix CLI)
      hm hm-check nix-audit nix-health nix-fmt nix-fix nix-gc nix-up
      alejandra statix deadnix nixd nil nix-tree nix-diff nvd nom nh
      manix nix-init nix-search-tv comma cachix devenv
      nix-index nix-locate nix-du nix-melt dix nix-update nix-prefetch
      nixpkgs-hammering nurl optnix angrr nixpkgs-review
      nix-output-monitor nix-diff vulnix nix-fast-build colmena deploy-rs
      nix-pkg-find nix-store-du nix-lock nix-dix nix-pkg-update
      nix-nurl nix-opt nix-review cached-nix-shell
      nix-ld angrr

    Virtualisation (awesome-nix + awesome-linux-containers)
      extra-container → nix-ctr     nixos-shell → nix-vm
      arion → nix-compose           distrobox lazydocker nerdctl runc youki
      podman buildah skopeo dive podman-tui    (see also: dk dkc dkps in zsh)

    Modern CLI (awesome-cli-apps)
      eza bat fd rg fzf zoxide delta glow difftastic topgrade
      dust duf procs btop hyperfine tokei tldr→cs cheat navi fx jc
      bottom gdu broot ncdu watchexec mosh mtr doggo dog gron choose sd
      television ast-grep atac posting oha trippy zellij just fq
      gum pueue mprocs sad jqp viddy entr csvlens

    Bare-metal Arch + Niri + DMS (pacman via arch-deps)
      niri xdg-desktop-portal xdg-desktop-portal-gtk polkit
      wl-clipboard cliphist grim slurp fuzzel wlogout swayidle
      dms-shell quickshell dgop matugen (from Nix HM)

    Verify install:  tools-check
    Discovery:       nix-search-tv  manix  nix-opt
      https://search.nixos.org
      https://home-manager-options.extranix.com
      https://noogle.dev
    EOF
  '';
in {
  home.packages = [
    commaRun
    nixPkgFind
    nixStoreDu
    nixLockMelt
    nixDix
    nixPkgUpdate
    nixNurl
    nixOptSearch
    nixReviewPr
    nixVmShell
    nixExtraCtr
    nixCompose
    cheatSheet
    awesomeList
    toolsCheck
    hmSwitch
    hmCheck
    nixAudit
    nixFmt
    nixGc
    nixUp
    nixHealth
    whocaresSwitch
    aegisSwitch

    # ── awesome-nix · Command-Line Tools (not in health.nix) ───────────────
    pkgs.nh
    pkgs.nix-output-monitor
    pkgs.nix-diff
    pkgs.nix-init
    pkgs.manix
    pkgs.vulnix
    pkgs.nix-fast-build
    pkgs.nix-du
    pkgs.nix-melt
    pkgs.dix
    pkgs.nix-update
    pkgs.nix-prefetch
    pkgs.nixpkgs-hammering
    pkgs.nurl
    pkgs.optnix
    pkgs.angrr
    pkgs.nil
    pkgs.colmena
    pkgs.deploy-rs
    pkgs.age-plugin-yubikey
    # nixpkgs-review pulled in by nixReviewPr wrapper — do not add both (PATH clash on nix-review)

    # ── awesome-nix · bare-metal Arch (not NixOS) ─────────────────────────
    pkgs.nix-ld

    # ── awesome-nix · Development ─────────────────────────────────────────
    pkgs.cached-nix-shell
    pkgs.arion

    # ── awesome-nix · Virtualisation ──────────────────────────────────────
    pkgs.extra-container
    pkgs.nixos-shell

    # ── awesome-linux-containers ──────────────────────────────────────────
    pkgs.distrobox
    pkgs.lazydocker
    pkgs.nerdctl
    pkgs.runc
    pkgs.youki

    # ── awesome-cli-apps · daily drivers (non-duplicates vs home.nix) ─────
    pkgs.tealdeer
    pkgs.cheat
    pkgs.navi
    pkgs.fx
    pkgs.jc
    pkgs.bottom
    pkgs.gdu
    pkgs.broot
    pkgs.ncdu
    pkgs.watchexec
    pkgs.mosh
    pkgs.mtr
    pkgs.doggo
    pkgs.dog
    pkgs.amass
    pkgs.topgrade
    pkgs.glow
    pkgs.difftastic
    pkgs.just
    pkgs.television
    pkgs.ast-grep
    pkgs.atac
    pkgs.posting
    pkgs.oha
    pkgs.trippy
    pkgs.podman-tui
    pkgs.zellij
    pkgs.fq
    pkgs.gum
    pkgs.pueue
    pkgs.mprocs
    pkgs.sad
    pkgs.jqp
    pkgs.viddy
    pkgs.entr
    pkgs.csvlens
  ];

  # Persistent background command queue from awesome-cli-apps.
  services.pueue.enable = true;

  # ── direnv + nix-direnv (awesome-nix Development) ───────────────────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  home.sessionVariables = {
    NIX_INDEX_GITHUB_TOKEN = ""; # avoid stale token errors; public cache is enough
    DIRENV_LOG_FORMAT = "";
  };

  # Build nix-index database once (comma + nix-locate depend on it)
  home.activation.buildNixIndex = lib.hm.dag.entryAfter ["writeBoundary"] ''
    INDEX="$HOME/.cache/nix-index/files"
    if [[ ! -f "$INDEX" ]]; then
      echo "[activation] Building nix-index database (first run, may take a minute)..."
      $DRY_RUN_CMD ${nixIndex} 2>/dev/null || echo "  (skipped — run: nix-index)"
    fi
  '';

  xdg.dataFile."aegis/awesome-tools.md".text = ''
    # Awesome-list toolchain — quick reference

    Run `awesome-list` in a terminal for the live inventory.

    ## Nix discovery
    | Command | Source list | Purpose |
    |---------|-------------|---------|
    | `nix-search-tv` | awesome-nix | Fuzzy package + HM option search |
    | `nix-pkg-find <term>` | awesome-nix | Search + nix-locate combined |
    | `manix <option>` | awesome-nix | Option docs in terminal |
    | `nix-opt` | awesome-nix | TUI module option search (optnix) |
    | `, <cmd>` | awesome-nix | Run any binary once (comma) |

    ## Nix maintenance
    | Command | Source list | Purpose |
    |---------|-------------|---------|
    | `nix-store-du` | awesome-nix | Visualize store disk usage (nix-du) |
    | `nix-lock` | awesome-nix | Browse flake.lock (nix-melt) |
    | `nix-dix` | awesome-nix | Fast derivation diff (dix) |
    | `nix-pkg-update` | awesome-nix | Bump package version/hash |
    | `nix-nurl <url>` | awesome-nix | Generate fetcher snippet (nurl) |
    | `nix-review pr-<n>` | awesome-nix | Test nixpkgs PR locally |
    | `angrr` | awesome-nix | Prune stale GC auto-roots |

    ## Logic and workflow
    | Command | Purpose |
    |---------|---------|
    | `pueue` / `pq` | Queue, group, pause, and inspect background commands |
    | `mprocs` / `mp` | Run and monitor several long-lived processes |
    | `sad` / `sr` | Preview and apply search-and-replace changes |
    | `jqp` / `jqx` | Explore JSON interactively with jq filters |
    | `viddy` / `watch` | Watch command output with history and diffs |
    | `entr` | Re-run commands when files change |
    | `csvlens` / `csv` | Inspect CSV data interactively |
    | `gum` | Build readable interactive shell workflows |

    ## Containers / VMs
    | Command | Source list | Purpose |
    |---------|-------------|---------|
    | `nix-vm` | awesome-nix | Ephemeral NixOS VM (nixos-shell) |
    | `nix-ctr` | awesome-nix | Declarative NixOS container |
    | `nix-compose` | awesome-nix | docker-compose via Nix (arion) |
    | `distrobox-create` | containers | Persistent pet containers |
    | `lazydocker` | awesome-linux-containers | TUI for podman/docker |
    | `nerdctl` | awesome-linux-containers | containerd CLI |

    ## Verify
    ```bash
    tools-check    # PATH audit for all integrated tools
    awesome-list   # human-readable inventory
    arch-deps      # sync Arch-only system packages (niri, portals, …)
    ```
    ```bash
    echo 'use flake' > .envrc && direnv allow
    ```
    nix-direnv caches shells — subsequent `cd` is instant.
  '';

  programs.zsh.shellAliases = {
    # awesome-nix
    "," = "comma";
    ni = "nix-index";
    nloc = "nix-locate";
    nfind = "nix-pkg-find";
    ndu = "nix-store-du";
    nlock = "nix-lock";
    ndix = "nix-dix";
    nupd = "nix-pkg-update";
    nurl = "nix-nurl";
    nopt = "nix-opt";
    nreview = "nix-review";
    nvm = "nix-vm";
    nctr = "nix-ctr";
    ncompose = "nix-compose";
    cns = "cached-nix-shell";
    awesome = "awesome-list";
    tcheck = "tools-check";

    # awesome-nix · Arch hybrid
    nixld = "nix-ld";

    # awesome-cli-apps
    cs = "tealdeer";
    help = "tealdeer";
    cheats = "cheat";
    cheat = "cheat";
    nav = "navi";
    w = "watchexec";
    ping = "doggo";
    dig = "dog";
    md = "glow";
    dft = "difftastic";
    upall = "topgrade";
    mp = "mprocs";
    pq = "pueue";
    sr = "sad";
    jqx = "jqp";
    watch = "viddy";
    csv = "csvlens";

    # awesome-linux-containers shortcuts
    lzd = "lazydocker";
    dbx = "distrobox";
    ndctl = "nerdctl";
  };

  programs.nushell.extraConfig = ''
    alias awesome   = awesome-list
    alias tcheck    = tools-check
    alias nfind     = nix-pkg-find
    alias ndu       = nix-store-du
    alias nlock     = nix-lock
    alias nvm       = nix-vm
    alias nctr      = nix-ctr
    alias lzd       = lazydocker
    alias cs        = tealdeer
    alias mp        = mprocs
    alias pq        = pueue
    alias sr        = sad
    alias jqx       = jqp
    alias watch     = viddy
    alias csv       = csvlens
  '';
}
