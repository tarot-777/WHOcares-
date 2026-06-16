# ---------------------------------------------------------------------------
# zsh.nix — Aegis-Dualis ZSH Home Manager module
#
# Self-contained: brings its own shell packages, aliases, history, and
# Nix-managed plugin bootstrap.
#
# Design:
#   • no runtime GitHub clone on shell startup
#   • zsh-vi-mode replaces the raw bindkey -v pattern for full vi behaviour
#   • fzf-tab provides context-aware tab completion previews
#   • starship, zoxide, atuin, and carapace integrations are managed by HM
# ---------------------------------------------------------------------------
{
  config,
  hostName ? "coffin",
  lib,
  nixosHostName ? "Aegis-Dualis",
  pkgs,
  userName ? "malachi",
  ...
}: {
  programs.zsh = {
    enable = true;
    # XDG-compliant: ~/.config/zsh  (relative to homeDirectory)
    # Absolute path as required by current HM (relative paths deprecated)
    dotDir = "${config.xdg.configHome}/zsh";

    # Home Manager loads completion before the declarative plugin set.
    enableCompletion = true;
    completionInit = ''
      autoload -Uz compinit
      mkdir -p "''${XDG_CACHE_HOME:-''${HOME}/.cache}/zsh"
      ZSH_COMPDUMP="''${XDG_CACHE_HOME:-''${HOME}/.cache}/zsh/zcompdump"
      compinit -d "''${ZSH_COMPDUMP}"
      _comp_options+=(globdots)
    '';
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Plugins are immutable nixpkgs inputs. `nix-up && hm` upgrades and
    # activates them; no shell startup performs network access or Git clones.
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
      {
        name = "zsh-autopair";
        src = pkgs.zsh-autopair;
        file = "share/zsh/zsh-autopair/autopair.zsh";
      }
      {
        name = "zsh-history-substring-search";
        src = pkgs.zsh-history-substring-search;
        file = "share/zsh-history-substring-search/zsh-history-substring-search.zsh";
      }
      {
        name = "you-should-use";
        src = pkgs.zsh-you-should-use;
        file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
      }
      {
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions;
        file = "share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
      }
      {
        name = "zsh-nix-shell";
        src = pkgs.zsh-nix-shell;
        file = "share/zsh-nix-shell/nix-shell.plugin.zsh";
      }
    ];

    history = {
      size = 100000;
      save = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
      extended = true; # save timestamps
    };

    shellAliases = {
      # ── Editors ─────────────────────────────────────────────────────────
      v = "nvim";
      vim = "nvim";

      # ── Modern Unix replacements ─────────────────────────────────────────
      ls = "eza --icons=auto --group-directories-first";
      ll = "eza -la --icons=auto --group-directories-first --header --git";
      la = "eza -a --icons=auto";
      lt = "eza --tree --level=2 --icons=auto";
      tree = "eza --tree --icons=auto";
      cat = "bat --style=plain --paging=never";
      diff = "delta";
      grep = "rg --color=auto";
      ff = "fd";
      top = "btop";
      du = "dust";
      df = "duf";
      ps = "procs";

      # ── Navigation ───────────────────────────────────────────────────────
      # cd is handled by zoxide eval — no alias needed
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      c = "clear";
      home = "cd ~";
      dots = "cd \"$AEGIS_FLAKE\"";
      cfg = "cd \"${config.home.homeDirectory}/WHOcares!\"";
      root = "whocares-cd";
      edit = "whocares-edit";
      guide = "whocares-guide";
      aliases = "whocares-guide";
      reload = "exec zsh";

      # ── Git ──────────────────────────────────────────────────────────────
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gb = "git branch";
      gc = "git commit";
      gco = "git checkout";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git log --oneline --decorate --graph --all";
      gp = "git push";
      gpl = "git pull --rebase";
      gs = "git status --short --branch";
      lg = "lazygit";

      # ── Nix / Home Manager / NixOS workflow ─────────────────────────────
      nb = "nix build";
      nd = "nix develop";
      ne = "nix eval";
      nfl = "nix flake";
      nr = "nix run";
      nrpl = "nix repl";
      ns = "nix shell";
      nshow = "nix flake show";
      nfc = "nix-check";
      ndev = "nix-develop";
      nfmt = "nix-fmt";
      naudit = "nix-audit";
      nhealth = "nix-health";
      ngc = "nix-gc";
      nup = "nix-up";
      nq = "nix search nixpkgs";
      nwhy = "nix why-dep";
      npath = "nix path-info -Sh";
      ndrv = "nix derivation show";
      hmb = "home-build";
      hmc = "hm-check";
      hms = "home-switch";
      hmu = "nix-up && home-switch";
      os = "whocares";
      oss = "whocares";
      osb = "nixos-build";
      ost = "nixos-test";
      osboot = "nixos-boot";
      osdry = "nixos-dry";
      osvm = "nixos-vm";
      target = "nix-target";
      daily = "nix-daily";
      ndaily = "nix-daily";
      zpl = "zsh-plugins";
      zpr = "exec zsh";
      zpu = "nix-up && hm";

      # ── Systemd / logs ───────────────────────────────────────────────────
      sc = "systemctl";
      scu = "systemctl --user";
      jc = "journalctl";
      jcu = "journalctl --user";
      jxe = "journalctl -xe";
      jxu = "journalctl --user -xe";
      bootlog = "journalctl -b -p warning..alert";
      userlog = "journalctl --user -b -p warning..alert";

      # ── Network / privacy ────────────────────────────────────────────────
      px = "proxychains4 -q";
      torify = "torsocks";
      ports = "ss -tulpn";
      netmon = "bandwhich";

      # ── Security tooling shortcuts ───────────────────────────────────────
      msf = "msfconsole -q";
      bp = "burpsuite";

      # ── Wayland clipboard ─────────────────────────────────────────────────
      wclip = "wl-copy";
      wpaste = "wl-paste";

      # Nix / HM command wrappers come from awesome-tools.nix:
      # hm, hm-check, nix-health, nix-gc, nix-up, nix-audit, nix-fmt, aegis

      # Media aliases → media.nix (play, vid, shuffle, queue)

      # ── Container ─────────────────────────────────────────────────────────
      dk = "podman";
      dkc = "podman-compose";
      dkps = "podman ps -a";

      # Whonix aliases are provided by whonix.nix.
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        # Extend completion lookup before Home Manager runs compinit.
        fpath=(
          ${pkgs.zsh-completions}/share/zsh/site-functions
          ${pkgs.nix-zsh-completions}/share/zsh/site-functions
          $fpath
        )

        # Plugin settings must exist before plugins are sourced (order 900).
        ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
        KEYTIMEOUT=1
        YSU_MESSAGE_POSITION=after
      '')
      (lib.mkOrder 1000 ''
          # fzf-tab contextual preview rules
          zstyle ':completion:*' menu select
          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
          zstyle ':completion:*:descriptions' format '[%d]'
          zstyle ':fzf-tab:complete:cd:*' \
            fzf-preview 'eza --tree --level=2 --color=always --icons $realpath'
          zstyle ':fzf-tab:complete:systemctl-*:*' \
            fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
          zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
            fzf-preview 'echo $word'
          zstyle ':fzf-tab:complete:kill:argument-rest' \
            fzf-preview '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-header -w -w'
          zstyle ':fzf-tab:complete:nix:*' \
            fzf-preview 'nix-env --query $word 2>/dev/null || echo $word'

          # Quick directory creation and fuzzy navigation.
          mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
          cdf() {
            local dir
            dir=$(fd --type d --hidden --exclude .git | fzf --preview 'eza --tree --level=2 --color=always --icons {}')
            [[ -n "$dir" ]] && cd -- "$dir"
          }

          # Select and terminate a user-owned process.
          fkill() {
            local pid
            pid=$(ps -u "$USER" -o pid=,command= | fzf --multi | awk '{print $1}')
            [[ -n "$pid" ]] && echo "$pid" | xargs kill --
          }

          # Extract common archive formats.
          extract() {
            [[ -f "$1" ]] || { echo "Usage: extract <archive>" >&2; return 2; }
            case "$1" in
              *.tar.bz2|*.tbz2) tar xjf "$1" ;;
              *.tar.gz|*.tgz) tar xzf "$1" ;;
              *.tar.xz|*.txz) tar xJf "$1" ;;
              *.tar.zst|*.tzst) tar --zstd -xf "$1" ;;
              *.zip) unzip "$1" ;;
              *.7z) 7z x "$1" ;;
              *.gz) gunzip "$1" ;;
              *.bz2) bunzip2 "$1" ;;
              *.xz) unxz "$1" ;;
              *) echo "Unsupported archive: $1" >&2; return 2 ;;
            esac
          }

          # Serve the current directory over HTTP.
          serve() { python3 -m http.server "''${1:-8000}"; }

          # Jump to the current repository root.
          git-root() {
            local root
            root=$(git rev-parse --show-toplevel 2>/dev/null) || return
            cd -- "$root"
          }

        # Show the immutable plugin inventory and update workflow.
        zsh-plugins() {
          printf '%s\n' \
            'Nix-managed Zsh plugins' \
            '  fzf-tab          ${pkgs.zsh-fzf-tab.version}' \
            '  zsh-vi-mode      ${pkgs.zsh-vi-mode.version}' \
            '  zsh-autopair     ${pkgs.zsh-autopair.version}' \
            '  history-search   ${pkgs.zsh-history-substring-search.version}' \
            '  you-should-use   ${pkgs.zsh-you-should-use.version}' \
            '  nix-completions  ${pkgs.nix-zsh-completions.version}' \
            '  zsh-nix-shell    ${pkgs.zsh-nix-shell.version}' \
            "" \
            'Commands' \
            '  zpl              show this inventory' \
            '  zpr              reload Zsh' \
            '  daily            show Nix, Home Manager, and NixOS shortcuts' \
            '  zpu              update flake inputs and run Home Manager switch'
        }

          # Distrobox has no shell-init hook. Completion is supplied by
          # Home Manager, carapace, and fzf-tab through normal PATH discovery.

        # Locate the nearest flake root, falling back to the configured framework.
        nix-root() {
          local root="$PWD"
          while [[ "$root" != "/" && ! -f "$root/flake.nix" ]]; do
            root="''${root:h}"
          done
          if [[ -f "$root/flake.nix" ]]; then
            print -r -- "$root"
          else
            print -r -- "''${WHOCARES_FLAKE:-''${AEGIS_FLAKE:-$PWD}}"
          fi
        }

        nix-check() {
          local root
          root="$(nix-root)" || return
          nix flake check --no-build --show-trace "path:$root" "$@"
        }

        nix-develop() {
          local root
          root="$(nix-root)" || return
          nix develop "path:$root" "$@"
        }

        home-build() {
          local root
          root="$(nix-root)" || return
          WHOCARES_FLAKE="$root" hm-check "$@"
        }

        home-switch() {
          local root
          root="$(nix-root)" || return
          WHOCARES_FLAKE="$root" hm "$@"
        }

        whocares-edit() {
          local root editor
          root="$(nix-root)" || return
          editor="''${EDITOR:-nvim}"
          "$editor" "$root"
        }

        whocares-cd() {
          local root
          root="$(nix-root)" || return
          cd -- "$root"
        }

        nix-target() {
          local root host
          root="$(nix-root)" || return
          host="''${WHOCARES_NIXOS_HOST:-''${AEGIS_NIXOS_HOST:-${nixosHostName}}}"
          print -r -- "path:$root#$host"
        }

        nix-daily() {
          local root host profile
          root="$(nix-root)" || return
          host="''${WHOCARES_NIXOS_HOST:-''${AEGIS_NIXOS_HOST:-${nixosHostName}}}"
          profile="''${WHOCARES_PROFILE:-''${AEGIS_PROFILE:-${userName}@''${AEGIS_HOST:-${hostName}}}}"

          printf '%s\n' \
            'WHOcares! daily Nix commands' \
            "  flake: $root" \
            "  home:  $profile" \
            "  nixos: $host" \
            "  guide: whocares-guide" \
            "" \
            'Checks and formatting' \
            '  nfc      nix flake check --no-build --show-trace for nearest flake' \
            '  nfmt     run Alejandra through nix-fmt' \
            '  naudit   run Deadnix and Statix checks' \
            '  nhealth  show flake outputs and build Home Manager' \
            "" \
            'Home Manager' \
            '  hmb      build nearest Home Manager flake' \
            '  hms      switch nearest Home Manager flake' \
            '  hmu      update flake inputs, then switch Home Manager' \
            '  hm-check low-priority configured Home Manager build' \
            "" \
            'NixOS host' \
            '  osb      build selected NixOS host' \
            '  ost      test selected NixOS host with sudo' \
            '  osboot   set selected NixOS host for next boot with sudo' \
            '  oss/os   switch selected NixOS host with sudo' \
            '  osdry    dry-build selected NixOS host' \
            "" \
            'System and terminal' \
            '  bootlog  warnings and errors from the current boot' \
            '  userlog  user-service warnings and errors from the current boot' \
            '  guide    aliases, functions, Kitty, and tmux quick reference' \
            '  kdash    open Kitty with Fastfetch, daily commands, and git status' \
            '  whocares-edit  open the nearest flake root in $EDITOR' \
            "" \
            'Discovery and cleanup' \
            '  nfind    search nixpkgs and nix-locate' \
            '  nopt     search NixOS/Home Manager options' \
            '  nlock    browse flake.lock' \
            '  nup      update flake inputs' \
            '  ngc      collect old Nix generations'
        }

        # History substring search keeps Up/Down useful after partial typing.
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down
        bindkey '^[OA' history-substring-search-up
        bindkey '^[OB' history-substring-search-down

        # Quick nix-shell for a package without entering devshell
        nix-run() { nix run nixpkgs#"$1" -- "''${@:2}"; }

        # Spin up a temporary devshell with arbitrary packages
        nix-tmp() {
          local pkgs_arg
          pkgs_arg=$(printf "nixpkgs#%s " "$@")
          nix shell $pkgs_arg
        }

        # Passive OSINT — wraps subfinder + amass + httpx
        osint-passive() {
          local domain="$1" out="$WHYCARE_HOME/recon/$1"
          mkdir -p "$out"
          echo "[*] subfinder"
          subfinder -d "$domain" -silent -o "$out/subfinder.txt"
          echo "[*] amass passive"
          amass enum -passive -d "$domain" -o "$out/amass.txt"
          echo "[*] httpx probe"
          cat "$out/subfinder.txt" "$out/amass.txt" | sort -u \
            | httpx -silent -title -status-code -tech-detect -o "$out/live.txt"
          echo "[+] Done → $out"
        }

        # JWT decode (no verification — OSINT use)
        jwt-decode() {
          local header payload
          header=$(echo "$1"  | cut -d. -f1 | base64 -d 2>/dev/null | jq .)
          payload=$(echo "$1" | cut -d. -f2 | base64 -d 2>/dev/null | jq .)
          echo "=== HEADER ==="; echo "$header"
          echo "=== PAYLOAD ==="; echo "$payload"
        }

        # Check current Tor circuit exit
        tor-status() {
          curl -s --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip | jq .
        }

        # Rotate Tor circuit
        tor-newnym() {
          echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' \
            | nc -q1 127.0.0.1 9051
        }

        # Show all open ports
        listening() { ss -tulpn | grep LISTEN; }
      '')
    ];
  };

  # Packages required by the above shell config that are not already in
  # home.packages (deduplication is safe — Home Manager ignores duplicates).
  home.packages = with pkgs; [
    eza
    bat
    fd
    ripgrep
    fzf
    zoxide
    starship
    carapace # shell completions bridge
    atuin # encrypted history sync
    nushell # available as `nu` even when zsh is default
    p7zip
    unzip
  ];
}
