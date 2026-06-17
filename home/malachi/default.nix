# ---------------------------------------------------------------------------
# home.nix — Aegis-Dualis standalone Home Manager root
#
# What lives here:
#   • home.* identity / stateVersion / sessionVariables / packages
#   • catppuccin + stylix theme engine config
#   • gtk, kitty, nushell, starship, programs that are NOT in their own module
#
# What is intentionally absent:
#   • programs.zsh  → lives in ./zsh.nix (imported via flake.nix)
#   • NixOS host settings → hosts/aegis-dualis/default.nix
#   • nixpkgs.config.allowUnfree → set in flake.nix pkgs instantiation
# ---------------------------------------------------------------------------
{
  config,
  lib,
  pkgs,
  flakeRoot ? "/home/malachi/Documents",
  hostName ? "coffin",
  homeDirectory ? "/home/malachi",
  userEmail ? "malachi@aegis-dualis",
  userName ? "malachi",
  ...
}: {
  imports = [
    ../modules/security.nix
    ../modules/shell.nix
    ../modules/llm-orchestrator.nix
    ../modules/profiles.nix
    ../modules/external-repos.nix
    ../modules/zsh.nix
    ../modules/whonix.nix
    ../modules/kitty.nix
    ../modules/tmux.nix
    ../modules/nvim.nix
    ../modules/dolphin.nix
    ../modules/media.nix
    ../modules/awesome-tools.nix
  ];

  # Feature switches are grouped under the framework's `whycare` namespace.
  whycare = {
    enableFullPower = false;
    shell.enable = true;
    externalRepos.enable = true;

    # Enable defensive security features (no deep tools by default)
    security = {
      enable = true;
      deep = {enable = false;};
    };

    llmOrchestrator = {
      enable = true;
      browser = "brave";
      maxFileBytes = 50000;
      maxFilesBrief = 35;
      maxFilesFull = 90;
    };

    profiles = {
      full.enable = false;
      graphics.enable = false;
      office.enable = false;
      vms.enable = false;
      rocm.enable = false;
      browser = "brave";
    };
  };

  # ── Identity ───────────────────────────────────────────────────────────────
  home = {
    username = userName;
    inherit homeDirectory;
    stateVersion = "25.05";

    # ── Session environment ─────────────────────────────────────────────────
    sessionVariables = {
      # AMD RX 480 — ROCm gfx803 compatibility shim
      HSA_OVERRIDE_GFX_VERSION = "8.0.3";
      LIBVA_DRIVER_NAME = "radeonsi";
      VDPAU_DRIVER = "radeonsi";

      # Wayland / Niri
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      GDK_BACKEND = "wayland";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_RUNTIME_DIR = "/run/user/1000";

      # Editor / pager
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "kitty";
      XDG_TERMINAL = "kitty";
      PAGER = "bat --style=plain";
      BAT_THEME = "Catppuccin Mocha";

      # Aegis paths
      WHYCARE_HOME = "${homeDirectory}/.whycare";
      AEGIS_FLAKE = flakeRoot;
      AEGIS_HOST = hostName;

      # Language toolchain homes
      PYTHONDONTWRITEBYTECODE = "1";
      PYTHONPYCACHEPREFIX = "${homeDirectory}/.cache/pycache";
      UV_CACHE_DIR = "${homeDirectory}/.cache/uv";
      GOPATH = "${homeDirectory}/go";
      GOBIN = "${homeDirectory}/go/bin";
      CARGO_HOME = "${homeDirectory}/.cargo";

      # Nix
      NIX_AUTO_INIT = "1";

      # Tor / proxychains default chain
      PROXY_CHAIN = "socks5 127.0.0.1 9050";
    };

    # ── User packages ───────────────────────────────────────────────────────
    # Organised by domain for easy maintenance.
    # Shell tooling lives in zsh.nix to co-locate with the shell config.
    packages = let
      # Disable heavy package sets by default.  Set `heavyEnabled = true` to include
      # heavyweight packages at build time.
      heavyEnabled = false;
    in
      with pkgs;
        [
          # ── Python scripting environment ──────────────────────────────────────
          (python3.withPackages (ps:
            with ps; [
              pyjwt
              netexec
              keystone-engine
              capstone
            ]))

          # ── Wayland / compositor tooling ──────────────────────────────────────
          swayidle
          wl-clipboard
          cliphist
          grim
          slurp
          swappy
          wlr-randr
          kanshi
          libnotify
          xdg-utils
          brightnessctl
          playerctl
          pavucontrol
          networkmanagerapplet
          fuzzel
          wlogout
          wf-recorder
          obs-studio

          # Graphics / Qt multimedia / Vulkan — required by Quickshell/DMS UI
          qt6Packages.qtmultimedia
          qt6Packages.qtbase
          vulkan-loader
          mesa

          # ── Modern Unix core replacements ─────────────────────────────────────
          # (eza bat fd ripgrep fzf zoxide also pulled by zsh.nix — HM dedupes)
          ripgrep
          fd
          bat
          eza
          delta
          fzf
          zoxide
          atuin
          btop
          bandwhich
          duf
          dust
          procs
          hyperfine
          hexyl
          tokei
          gping
          jless
          miller
          sd
          choose
          # ── Media & desktop apps (native Nix — no Flatpak) ───────────────────
          # mpv / celluloid / ffmpeg → media.nix
          # Dolphin / Ark / KIO plugins → dolphin.nix
          imv
          zathura
          gnome-text-editor
          gnome-control-center

          # ── Git toolchain ─────────────────────────────────────────────────────
          git
          git-lfs
          lazygit

          # ── Data / structured text ────────────────────────────────────────────
          jq
          yq-go
          gron
          dasel

          # ── Dev toolchains ────────────────────────────────────────────────────
          devbox
          rustup
          go

          # ── Container / VM tooling ────────────────────────────────────────────
          podman-compose
          skopeo
          buildah
          dive

          # ── HTTP / API clients ────────────────────────────────────────────────
          httpie
          curlie
          xh

          # Nix tooling → health.nix

          # ── Anonymization / privacy ───────────────────────────────────────────
          tor-browser
          proxychains-ng
          torsocks
          macchanger
          i2pd
          wireguard-tools
          firejail

          # ── OSINT / recon ─────────────────────────────────────────────────────
          subfinder
          amass
          httpx
          theharvester
          recon-ng
          nmap
          masscan
          rustscan
          nuclei
          ffuf
          gobuster
          feroxbuster
          nikto
          dnsx
          dnsrecon
          arping
          netdiscover
          cloudfox

          # ── Web app / exploitation ────────────────────────────────────────────
          sqlmap
          burpsuite
          mitmproxy

          # ── Password / credential attacks ─────────────────────────────────────
          john
          hashcat
          hashcat-utils
          seclists

          # ── Post-exploitation / AD ────────────────────────────────────────────
          metasploit
          bloodhound
          neo4j
          evil-winrm

          # ── Network interception ──────────────────────────────────────────────
          ettercap
          bettercap
          responder

          # ── Wireless ─────────────────────────────────────────────────────────
          aircrack-ng
          hcxdumptool
          hcxtools
          kismet
          horst

          # ── Hardware / firmware ───────────────────────────────────────────────
          flashrom
          openocd
          sigrok-cli
          pulseview
          minicom
          picocom
          sdcc

          # ── Forensics / reverse engineering ──────────────────────────────────
          volatility3
          sleuthkit
          exiftool
          steghide
          stegseek
          foremost
          scalpel
          # binwalk  # temporarily disabled to avoid build-time failures; re-enable when binary caches available
          xxd
          file
          binutils-unwrapped

          # ── Disassembly / debugging ────────────────────────────────────────────
          radare2
          rizin
          cutter
          ghidra
          gdb
          pwntools

          # ── Secrets management ────────────────────────────────────────────────
          age
          sops
          bitwarden-cli
          keepassxc

          # ── Productivity ──────────────────────────────────────────────────────
          obsidian
          evince
        ]
        ++ (lib.optionals heavyEnabled []);
  };

  # ── Home Manager self-management ───────────────────────────────────────────
  programs.home-manager.enable = true;

  # ── XDG base dirs ─────────────────────────────────────────────────────────
  xdg.enable = true;

  # ── Catppuccin theme engine ────────────────────────────────────────────────
  # autoEnable = true applies Catppuccin to every supported program that is
  # also enabled. Per-program overrides below disable duplicates managed by
  # Stylix to avoid conflicting theme injections.
  # Keep Catppuccin disabled to avoid file/provider conflicts; Stylix handles theming
  catppuccin = {
    enable = false;
    autoEnable = false;
  };

  # ── Stylix theming engine ──────────────────────────────────────────────────
  stylix = {
    enable = true;
    polarity = "dark";

    # Generated wallpaper — no external image dependency
    image =
      pkgs.runCommand "aegis-wallpaper.png" {
        nativeBuildInputs = [pkgs.imagemagick pkgs.fontconfig];
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [pkgs.noto-fonts pkgs.dejavu_fonts];
        };
      } ''
        export HOME="$TMPDIR"
        export XDG_CACHE_HOME="$TMPDIR"
        mkdir -p "$XDG_CACHE_HOME/fontconfig"
        FONT=$(fc-match -f '%{file}\n' 'Noto Sans' || fc-match -f '%{file}\n' 'DejaVu Sans')
        convert -size 3840x2160 \
          gradient:'#050006-#21001f' \
          -fill '#ff1744' -draw "rectangle 0,1079 3839,1080" \
          -fill '#ff2bd6' -font "$FONT" -pointsize 56 \
          -gravity SouthEast -annotate +100+60 'WHOcares! neon' \
          $out
      '';

    base16Scheme = {
      scheme = "WHOcares Neon";
      author = "Aegis-Dualis";
      slug = "whocares-neon";
      base00 = "050006"; # black
      base01 = "09000d";
      base02 = "120018";
      base03 = "21001f";
      base04 = "8e4f80";
      base05 = "ffd6f4";
      base06 = "ffe6fa";
      base07 = "ffffff";
      base08 = "ff1744"; # red
      base09 = "ff6b8a";
      base0A = "ff9f1c";
      base0B = "ff8ce6";
      base0C = "67e8f9";
      base0D = "a855f7"; # purple
      base0E = "ff2bd6"; # hot pink
      base0F = "d8b4fe";
    };

    fonts = {
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
      sansSerif = {
        package = pkgs.noto-fonts;
        name = "Noto Sans";
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 12;
        desktop = 11;
        popups = 12;
        terminal = 14;
      };
    };

    opacity = {
      applications = 1.0;
      desktop = 1.0;
      popups = 0.97;
      terminal = 0.95;
    };

    cursor = {
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
    };

    # Disable Stylix targets that Catppuccin manages above (avoid conflicts)
    targets = {
      gtk = {
        enable = true;
        # Flatpak is managed by Arch, not Nix — avoid ~/.local/share/flatpak/overrides/global clash.
        flatpakSupport.enable = false;
      };
      mako.enable = true;
      waybar.enable = false; # dms.nix — DankMaterialShell bar
      swaylock.enable = false; # desktop.nix — Catppuccin lock screen
      fzf.enable = false; # catppuccin.fzf.enable = true
      fuzzel.enable = false; # desktop.nix — full fuzzel.ini
      bat.enable = false; # catppuccin.bat.enable = true
      btop.enable = false; # catppuccin.btop.enable = true
      kitty.enable = false; # catppuccin.kitty via kitty.nix
      starship.enable = false; # managed by programs.starship.settings
    };
  };

  # ── GTK ────────────────────────────────────────────────────────────────────
  # Stylix injects gtk.theme / gtk.iconTheme / gtk.cursorTheme automatically
  # when stylix.targets.gtk.enable = true. Only enable the module here.
  gtk.enable = true;

  # Kitty terminal → kitty.nix

  # ── Nushell ────────────────────────────────────────────────────────────────
  programs.nushell = {
    enable = true;

    environmentVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "kitty";
      PAGER = "bat --style=plain";
      BAT_THEME = "Catppuccin Mocha";
      HSA_OVERRIDE_GFX_VERSION = "8.0.3";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      CARAPACE_BRIDGES = "zsh,fish,bash";
    };

    envFile.text = ''
      $env.GOPATH       = ($env.HOME | path join "go")
      $env.GOBIN        = ($env.HOME | path join "go" "bin")
      $env.CARGO_HOME   = ($env.HOME | path join ".cargo")
      $env.WHYCARE_HOME = ($env.HOME | path join ".whycare")
      $env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"

      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        ($env.HOME | path join ".nix-profile" "bin")
        ($env.HOME | path join ".local" "bin")
        ($env.HOME | path join "go" "bin")
        ($env.HOME | path join ".cargo" "bin")
        ($env.HOME | path join ".local" "share" "uv" "bin")
        "/nix/var/nix/profiles/default/bin"
      ] | uniq)

      $env.STARSHIP_SHELL = "nu"
    '';

    configFile.text = ''
      let carapace_completer = {|spans: list<string>|
        carapace $spans.0 nushell ...$spans
          | from json
          | if ($in | default [] | where value =~ '^-.*ERR$' | is-empty) { $in } else { null }
      }

      $env.config = {
        show_banner: false
        edit_mode: vi
        ls: { use_ls_colors: true clickable_links: true }
        rm: { always_trash: true }
        table: {
          mode: rounded index_mode: always show_empty: true
          trim: { methodology: wrapping wrapping_try_keep_words: true truncating_suffix: "..." }
        }
        error_style: fancy
        history: { max_size: 100000 sync_on_enter: true file_format: sqlite isolation: true }
        completions: {
          case_sensitive: false quick: true partial: true algorithm: fuzzy
          external: { enable: true max_results: 100 completer: $carapace_completer }
        }
        cursor_shape: { vi_insert: blink_line vi_normal: blink_block }
        use_ansi_coloring: true bracketed_paste: true
        shell_integration: { osc2: true osc7: true osc8: true osc133: true osc633: true }
        hooks: {
          pre_prompt: [{ null }]
          env_change: { PWD: [{ null }] }
          display_output: {|| if (term size).columns >= 120 { table -e } else { table } }
          command_not_found: {|| null }
        }
      }

      # ── Structured helpers ─────────────────────────────────────────────────
      def glog [n: int = 20] {
        ^git log --format="%H|%an|%ai|%s" -n $n | lines | each {|l|
          let p = ($l | split column "|")
          { hash:   ($p | get column1.0 | str substring 0..7)
            author: ($p | get column2.0)
            date:   ($p | get column3.0)
            msg:    ($p | get column4.0) }
        } | table
      }

      def nixsearch [pkg: string] {
        ^nix search nixpkgs $pkg --json | from json | transpose name info
        | each {|r| {
            name:        ($r.name | str replace "legacyPackages.x86_64-linux." "")
            version:     $r.info.version
            description: $r.info.description
        }} | table
      }

      def nix-root [] {
        mut root = $env.PWD
        loop {
          if (($root | path join "flake.nix") | path exists) {
            return $root
          }
          let parent = ($root | path dirname)
          if $parent == $root {
            return ($env.WHOCARES_FLAKE? | default $env.AEGIS_FLAKE? | default $env.PWD)
          }
          $root = $parent
        }
      }

      def ncheck [...args: string] {
        let root = (nix-root)
        ^nix flake check --no-build --show-trace $"path:($root)" ...$args
      }

      def ndev [...args: string] {
        let root = (nix-root)
        ^nix develop $"path:($root)" ...$args
      }

      def hmb [...args: string] {
        with-env { WHOCARES_FLAKE: (nix-root) } {
          ^hm-check ...$args
        }
      }

      def hms [...args: string] {
        with-env { WHOCARES_FLAKE: (nix-root) } {
          ^hm ...$args
        }
      }

      def hmu [...args: string] {
        with-env { WHOCARES_FLAKE: (nix-root) } {
          ^nix-safe-update ...$args
        }
      }

      # Passive OSINT pipeline — outputs to $WHYCARE_HOME/recon/<domain>
      def osint-passive [domain: string] {
        let out = ($env.WHYCARE_HOME | path join "recon" $domain)
        mkdir $out
        print $"[*] subfinder: ($domain)"
        ^subfinder -d $domain -silent -o ($out | path join "subfinder.txt")
        print $"[*] amass passive: ($domain)"
        ^amass enum -passive -d $domain -o ($out | path join "amass.txt")
        print $"[*] theHarvester: ($domain)"
        ^theHarvester -d $domain -b all -f ($out | path join "harvester") e>| ignore
        print $"[*] httpx probing..."
        ^cat ($out | path join "subfinder.txt") ($out | path join "amass.txt")
          | ^httpx -silent -title -status-code -tech-detect -o ($out | path join "live.txt")
        print $"[+] Done → ($out)"
      }

      # Full active pipeline — adds nuclei + ffuf
      def osint-active [
        domain: string
        wordlist: string = "/run/current-system/sw/share/seclists/Discovery/Web-Content/raft-medium-words.txt"
      ] {
        let ts  = (date now | format date "%s")
        let out = ($env.WHYCARE_HOME | path join "recon" $"($domain)_($ts)")
        osint-passive $domain
        print $"[*] nuclei scanning ($out)/live.txt ..."
        ^nuclei -l ($out | path join "live.txt") -silent -severity medium,high,critical \
          -o ($out | path join "nuclei.txt")
        print $"[*] ffuf content discovery..."
        for host in (open ($out | path join "live.txt") | lines) {
          let safe = ($host | str replace --all "/" "_")
          ^ffuf -u $"($host)/FUZZ" -w $wordlist -t 50 -mc 200,301,302,403 \
            -o ($out | path join $"ffuf_($safe).json") -of json -s
        }
        print $"[+] Active done → ($out)"
      }

      def jwt-decode [token: string] {
        let parts = ($token | split row ".")
        { header:  ($parts | get 0 | decode base64 --nopad | decode utf-8 | from json)
          payload: ($parts | get 1 | decode base64 --nopad | decode utf-8 | from json) }
      }

      def niri-windows [] {
        ^niri msg windows --json | from json | select id app_id title workspace_id | table
      }

      def sha256-str [input: string] {
        $input | ^sha256sum | split column " " | get column1.0
      }

      def tor-status [] {
        ^curl -s --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip | from json
      }

      # ── Aliases ──────────────────────────────────────────────────────────
      alias v      = nvim
      alias vim    = nvim
      alias ls     = eza --icons=auto --group-directories-first
      alias ll     = eza -la --icons=auto --group-directories-first --header --git
      alias la     = eza -a --icons=auto
      alias lt     = eza --tree --level=2 --icons=auto
      alias cat    = bat
      alias diff   = delta
      alias grep   = rg
      alias top    = btop
      alias g      = git
      alias lg     = lazygit
      alias px     = proxychains4 -q
      alias torify = torsocks
      alias msf    = msfconsole -q
      alias bp     = burpsuite
      alias wclip  = wl-copy
      alias wpaste = wl-paste
      alias guide  = whocares-guide
      alias aliases = whocares-guide
      # hm / nix-safe-update / nix-gc / nix-up → awesome-tools.nix wrappers
      alias dk     = podman
      alias dkc    = podman-compose
      alias dkps   = podman ps -a
      alias ports  = ss -tulpn
      alias netmon = bandwhich
      alias nfc    = ncheck
      alias hmc    = hm-check
      alias nshow  = nix flake show
      alias nfmt   = nix-fmt
      alias naudit = nix-audit
      alias nhealth = nix-health
      alias ngc    = nix-gc
      alias nup    = nix-up
      alias nwhy   = nix why-dep
      alias npath  = nix path-info -Sh
    '';
  };

  # ── Starship prompt ────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    # WHOcares! hot-pink / black / red / purple palette.
    settings = {
      format = lib.concatStrings [
        "$username$hostname$directory$git_branch$git_status"
        "$nix_shell$python$rust$golang$nodejs"
        "$cmd_duration$line_break$character"
      ];
      palette = lib.mkForce "whocares_neon";
      palettes.whocares_neon = {
        black = "050006";
        bg = "09000d";
        panel = "21001f";
        muted = "8e4f80";
        text = "ffd6f4";
        pink = "ff2bd6";
        pinksoft = "ff8ce6";
        red = "ff1744";
        redsoft = "ff6b8a";
        purple = "a855f7";
        purplesoft = "d8b4fe";
        cyan = "67e8f9";
      };
      character = {
        success_symbol = "[❯](bold pink)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold purple)";
      };
      directory = {
        style = "bold purple";
        truncation_length = 4;
        truncate_to_repo = true;
      };
      git_branch.style = "bold pink";
      git_status.style = "bold red";
      nix_shell = {
        style = "bold cyan";
        symbol = "❄️  ";
        impure_msg = "[impure](bold redsoft)";
        pure_msg = "[pure](bold pinksoft)";
      };
      cmd_duration = {
        min_time = 500;
        style = "bold redsoft";
      };
    };
  };

  # ── Carapace shell completions ─────────────────────────────────────────────
  programs.carapace = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };

  # ── Atuin shell history ────────────────────────────────────────────────────
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    settings = {
      style = "compact";
      inline_height = 20;
      show_preview = true;
      filter_mode_shell_up_key_binding = "session";
      sync_frequency = "5m";
      update_check = false;
    };
  };

  # ── Zoxide smart cd ────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };

  # ── Yazi file manager ──────────────────────────────────────────────────────
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
    shellWrapperName = "yy"; # explicit: keeps legacy behaviour
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
      };
    };
  };

  # Neovim → nvim.nix

  # ── Git ────────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    settings = {
      user.name = userName;
      user.email = userEmail;
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase.autoStash = true;
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
      core.pager = "delta";
      credential.helper = "store";
    };
  };

  # delta is now a standalone HM program (programs.git.delta.* was removed)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true;
      syntax-theme = "Catppuccin Mocha";
    };
  };

  # ── SSH client ─────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  # ── GPG ────────────────────────────────────────────────────────────────────
  programs.gpg = {
    enable = true;
    homedir = "${config.home.homeDirectory}/.gnupg";
    settings = {
      use-agent = true;
      personal-cipher-preferences = "AES256 TWOFISH AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      s2k-digest-algo = "SHA512";
      s2k-cipher-algo = "AES256";
      no-symkey-cache = true;
      throw-keyids = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    enableZshIntegration = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 86400;
    pinentry.package = pkgs.pinentry-gtk2;
  };

  # tmux → tmux.nix

  # ── bat (syntax highlighter / pager) ──────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      style = "numbers,changes,header";
      pager = "less -FR";
    };
  };

  # ── btop (system monitor) ─────────────────────────────────────────────────
  programs.btop = {
    enable = true;
    settings = {
      # color_theme set by catppuccin.btop.enable = true — do not duplicate
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      update_ms = 1000;
    };
  };

  # ── fzf (fuzzy finder) ────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height=40%"
      "--border=rounded"
      "--color=bg+:#21001f,bg:#050006,spinner:#ff2bd6,hl:#ff1744"
      "--color=fg:#ffd6f4,header:#ff2bd6,info:#a855f7,pointer:#ff2bd6"
      "--color=marker:#ff8ce6,fg+:#ffffff,prompt:#a855f7,hl+:#ff6b8a"
      "--color=border:#8e4f80"
    ];
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  # ── Mako notification daemon ───────────────────────────────────────────────
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      layer = "overlay";
      anchor = "top-right";
      margin = "10";
      padding = "10,15";
      border-radius = 8;
      border-size = 1;
      max-visible = 5;
    };
    # Colors injected by Stylix (stylix.targets.mako.enable = true)
  };

  # Waybar → replaced by DankMaterialShell (dms.nix)
  programs.waybar.enable = false;

  # Desktop launch defaults → qutebrowser, Dolphin, Kitty, and Kitty-hosted nvim.
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = ["kitty.desktop"];
      niri = ["kitty.desktop"];
      GNOME = ["kitty.desktop"];
      KDE = ["kitty.desktop"];
    };
  };

  xdg.desktopEntries = {
    kitty = {
      name = "Kitty";
      genericName = "Terminal Emulator";
      comment = "WHOcares neon Kitty terminal";
      exec = "${config.home.profileDirectory}/bin/kitty %U";
      icon = "kitty";
      terminal = false;
      categories = [
        "System"
        "TerminalEmulator"
      ];
      mimeType = ["x-scheme-handler/terminal"];
      startupNotify = true;
      settings = {
        Keywords = "shell;prompt;command;commandline;terminal;tmux;WHOcares;";
        X-TerminalArgExec = "-e";
        X-TerminalArgTitle = "--title";
      };
    };

    whocares-terminal-dashboard = {
      name = "WHOcares Terminal Dashboard";
      genericName = "Terminal Dashboard";
      comment = "Open the WHOcares Kitty dashboard with fastfetch, guide, git, and tmux shortcuts";
      exec = "${config.home.profileDirectory}/bin/kitty-framework dashboard";
      icon = "kitty";
      terminal = false;
      categories = [
        "System"
        "TerminalEmulator"
      ];
      startupNotify = true;
      settings.Keywords = "kitty;tmux;fastfetch;nix;home-manager;WHOcares;";
    };

    whocares-editor = {
      name = "WHOcares Neovim";
      genericName = "Text Editor";
      comment = "Open files in Neovim inside the WHOcares Kitty terminal";
      exec = "${config.home.profileDirectory}/bin/kitty --class whocares-editor --title WHOcares-Neovim -e ${config.home.profileDirectory}/bin/nvim %F";
      icon = "nvim";
      terminal = false;
      noDisplay = true;
      categories = [
        "Utility"
        "TextEditor"
        "Development"
      ];
      mimeType = [
        "application/json"
        "application/toml"
        "application/x-shellscript"
        "application/xml"
        "text/css"
        "text/html"
        "text/markdown"
        "text/plain"
        "text/x-c"
        "text/x-c++"
        "text/x-lua"
        "text/x-nix"
        "text/x-python"
        "text/x-rust"
        "text/x-script"
        "text/yaml"
      ];
      startupNotify = true;
      settings.Keywords = "nvim;neovim;editor;code;kitty;WHOcares;";
    };
  };

  # Dolphin defaults → dolphin.nix
  # MPV / Celluloid defaults → media.nix

  # ── XDG default apps (native Nix — no Flatpak) ─────────────────────────────
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = "org.gnome.Evince.desktop";
      "application/json" = "whocares-editor.desktop";
      "application/toml" = "whocares-editor.desktop";
      "application/x-shellscript" = "whocares-editor.desktop";
      "application/xhtml+xml" = "org.qutebrowser.qutebrowser.desktop";
      "image/jpeg" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/webp" = "imv.desktop";
      "text/css" = "whocares-editor.desktop";
      "text/html" = "org.qutebrowser.qutebrowser.desktop";
      "text/markdown" = "whocares-editor.desktop";
      "text/plain" = "whocares-editor.desktop";
      "text/x-lua" = "whocares-editor.desktop";
      "text/x-nix" = "whocares-editor.desktop";
      "text/x-python" = "whocares-editor.desktop";
      "text/x-rust" = "whocares-editor.desktop";
      "text/yaml" = "whocares-editor.desktop";
      "x-scheme-handler/chrome" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/terminal" = "kitty.desktop";
      "application/zip" = "file-roller.desktop";
    };
  };

  # ── Persist XDG user dirs declaratively ────────────────────────────────────
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true; # explicit: replaces deprecated legacy default
    documents = "${config.home.homeDirectory}/documents";
    download = "${config.home.homeDirectory}/downloads";
    pictures = "${config.home.homeDirectory}/pictures";
    videos = "${config.home.homeDirectory}/videos";
    music = "${config.home.homeDirectory}/music";
    desktop = "${config.home.homeDirectory}/desktop";
    publicShare = "${config.home.homeDirectory}/public";
    templates = "${config.home.homeDirectory}/templates";
  };

  # Nix daemon settings → health.nix

  # WHYcare defaults are declared near the top of this module.
}
