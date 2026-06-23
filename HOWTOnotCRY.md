# HOW TO not CRY

## Why WHOcares! Is More Than a Dotfiles Repository

WHOcares! is a reproducible workstation framework built around Nix flakes and
Home Manager. It turns shell behavior, editor plugins, terminal workflows,
desktop applications, media defaults, security tools, virtualization helpers,
and maintenance commands into one pinned configuration.

The project uses **WHOcares!** as its public name, **Aegis-Dualis** for the
experimental NixOS host, and the `whycare` option namespace for feature
switches.

The important distinction is:

- **Active defaults** are loaded by `home/malachi/default.nix`.
- **Optional features** exist but require a `whycare` switch.
- **Host scaffolding** describes a future NixOS machine and should not be
  treated as a ready-to-install disk configuration.

## The Foundation

Everything starts with `flake.nix`, `settings.nix`, and `lib/framework.nix`.
Together they provide:

- pinned dependencies through `flake.lock`;
- reusable constructors for Home Manager profiles and NixOS hosts;
- one identity and target registry in `settings.nix`;
- support for both generic Linux and integrated NixOS Home Manager;
- reusable overlays from Fenix and `nix-alien`;
- binary caches for NixOS, nix-community, Niri, Hyprland, MicroVM, and
  Numtide;
- a development shell with Nix, Home Manager, formatting, linting, and
  language-server tools;
- flake checks that run Alejandra, Statix, Deadnix, and ShellCheck;
- package, app, overlay, library, Home Manager, and NixOS outputs from one
  flake.

The main targets are:

| Target | Purpose |
|---|---|
| `homeConfigurations."malachi@coffin"` | Active generic-Linux workstation |
| `homeConfigurations."malachi@workstation"` | Portable Home Manager target for workstation installs |
| `homeConfigurations."malachi@laptop"` / `homeConfigurations."malachi@hp-laptop"` | Portable Home Manager targets for mobile installs |
| `homeConfigurations."malachi@Aegis-Dualis"` | Home profile evaluated for NixOS |
| `nixosConfigurations.Aegis-Dualis` | Experimental NixOS host scaffold |
| `nixosConfigurations.workstation`, `laptop`, `hp-laptop` | NixOS baselines for portable deployments |
| `devShells.aegis-dev` | Repository development environment |

The flake also exposes direct applications:

| Command | Purpose |
|---|---|
| `nix run .` | Show framework targets and capabilities |
| `nix run .#home-build` | Build the selected Home Manager profile |
| `nix run .#home-switch` | Activate the selected Home Manager profile |
| `nix run .#nixos-switch` | Rebuild the selected NixOS host |
| `nix run .#nixos-install -- <host> <ssh-target>` | Guarded `nixos-anywhere` deployment |
| `nix run .#check` | Evaluate flake outputs without building |
| `nix run .#update` | Update locked flake inputs |

## Deployment Lifecycle

WHOcares! supports three practical deployment paths.

### Generic Linux Home Manager

Use this path for Arch, Debian, Fedora, or another Linux system that already has
Nix available:

```sh
./install.sh --home-host workstation
nix run path:$HOME/WHOcares#home-build
nix run path:$HOME/WHOcares#home-switch
```

Use `--home-host laptop` or `--home-host hp-laptop` for portable laptop
profiles. The bootstrap script rewrites `settings.nix` for the target user,
home directory, checkout path, default Home Manager host, and default NixOS
host. After the first activation, `hm-check`, `hm`, `hmu`, `targets`, and
`installos` are available from the profile.

### Existing NixOS Machine

Use this path when the system is already NixOS and should switch to one of the
framework host outputs:

```sh
cp /etc/nixos/hardware-configuration.nix hosts/workstation/hardware-configuration.nix
WHOCARES_NIXOS_HOST=workstation nix run path:$HOME/WHOcares#nixos-switch
```

Before switching, review boot loader, filesystems, host name, users, networking,
and state version. The portable `workstation`, `laptop`, and `hp-laptop` hosts
are hardware-neutral baselines until a real hardware file is added.

### Fresh NixOS Install

Fresh installs are destructive by nature, so the wrapper refuses to proceed
until the target host has a declared disk layout:

```text
hosts/<host>/hardware-configuration.nix
hosts/<host>/disko.nix
```

Then run:

```sh
nix run path:$HOME/WHOcares#nixos-install -- <host> root@<target-ip>
```

The installed Home Manager command `whocares-install` is the same guarded path.
Set `WHOCARES_INSTALL_WITHOUT_DISKO=1` only for a deliberate pre-mounted or
custom `nixos-anywhere` phase.

### Runtime Overrides

| Variable | Purpose |
|---|---|
| `WHOCARES_FLAKE` / `AEGIS_FLAKE` | Checkout path or flake ref |
| `WHOCARES_HOST` / `AEGIS_HOST` | Home Manager host suffix |
| `WHOCARES_PROFILE` / `AEGIS_PROFILE` | Full Home Manager profile |
| `WHOCARES_NIXOS_HOST` / `AEGIS_NIXOS_HOST` | NixOS host output |
| `WHOCARES_NIX_JOBS` / `WHOCARES_NIX_CORES` | Build parallelism limits |
| `WHOCARES_NICE` | Niceness for heavy wrapper commands |
| `WHOCARES_MIN_FREE_GB` | Minimum free `/nix/store` space for safe updates |
| `WHOCARES_ALLOW_LOCAL_BUILDS` | Allow source builds during safe update |
| `WHOCARES_MAX_LOCAL_BUILDS` | Numeric source-build allowance |

## A Coherent Visual Identity

The workstation uses Catppuccin Mocha as a shared visual language rather than
theming each program independently.

Active theme customizations include:

- Catppuccin Mocha with a mauve accent;
- Stylix-generated GTK, font, cursor, opacity, and notification settings;
- a generated 3840x2160 Aegis-Dualis wallpaper with no external image
  dependency;
- JetBrains Mono Nerd Font for terminals and code;
- Noto Sans, Noto Serif, and Noto Color Emoji for desktop applications;
- Catppuccin integration for Kitty, tmux, Bat, Btop, Delta, fzf, Lazygit, and
  Zsh syntax highlighting;
- a hand-tuned Catppuccin Starship palette;
- a Wayland-first environment for Mozilla, Qt, GTK, SDL, and terminal apps.

The theme ownership is deliberately split between Catppuccin and Stylix so
both modules do not try to generate the same files.

## Zsh: Fast, Pinned, and Network-Free at Startup

Zsh is the primary shell. Home Manager owns its history, completion setup,
aliases, integrations, and plugin paths. Shell startup never clones a plugin
repository.

### Zsh plugins

| Plugin | Customization |
|---|---|
| `fzf-tab` | Fuzzy completion with previews for directories, processes, systemd, and Nix |
| `zsh-vi-mode` | Full vi editing with `jk` as the insert-mode escape chord |
| `zsh-autopair` | Automatic matching quotes, brackets, and braces |
| `zsh-you-should-use` | Reminds the user when an existing alias matches a command |
| `nix-zsh-completions` | Nix command and option completion |
| `zsh-nix-shell` | Preserves the configured Zsh experience inside `nix-shell` |
| Home Manager autosuggestions | Inline command suggestions |
| Home Manager syntax highlighting | Live shell syntax feedback |

History keeps 100,000 timestamped entries, shares them between sessions, and
ignores duplicate and space-prefixed commands.

### Shell integrations

- **Starship** shows user, host, directory, Git state, language toolchains,
  Nix shell state, and command duration.
- **Atuin** adds searchable history with session filtering and optional sync.
- **Carapace** bridges completions into both Zsh and Nushell.
- **Zoxide** supplies frecency-based directory jumping.
- **fzf** searches hidden files and directories with a Catppuccin UI.
- **Yazi** supplies terminal file management through `yy`.
- **direnv + nix-direnv** automatically load and cache project environments.

### Shell helpers

WHOcares! adds nearest-flake discovery, so framework commands work from inside
nested project directories:

- `nfc` / `nix-check` runs a no-build flake check;
- `ndev` / `nix-develop` enters the nearest development shell;
- `home-build` builds the nearest Home Manager flake;
- `home-switch` activates it;
- `hmu` / `nix-safe-update` updates inputs, checks evaluation, refuses local
  source builds by default, builds, shows an `nvd` diff, then switches only
  after those steps pass. Override with `WHOCARES_ALLOW_LOCAL_BUILDS=1` or
  `WHOCARES_MAX_LOCAL_BUILDS=N`;
- `whocares-targets` lists workstation, laptop, and HP laptop deployment names;
- `whocares-install` wraps `nixos-anywhere` for guarded fresh NixOS installs
  once `hosts/<host>/hardware-configuration.nix` and `hosts/<host>/disko.nix`
  are explicit;
- `nix-run` runs a package without installing it;
- `nix-tmp` opens a temporary shell with arbitrary packages.

It also adds `mkcd`, `cdf`, `fkill`, `extract`, `serve`, `git-root`,
`osint-passive`, `jwt-decode`, `tor-status`, `tor-newnym`, and `listening`.

Modern command aliases replace traditional tools with `eza`, `bat`, `rg`,
`fd`, `delta`, `btop`, `dust`, `duf`, and `procs`.

Run:

```sh
zpl       # pinned Zsh plugin inventory
awesome   # installed toolchain inventory
tcheck    # check whether integrated commands are available
```

## Nushell: Structured Data as a First-Class Workflow

Nushell is available alongside Zsh and shares Starship, Atuin, Carapace,
Zoxide, Yazi, direnv, media, Whonix, and framework integrations.

Its custom configuration includes:

- vi editing;
- SQLite history with 100,000 entries;
- fuzzy external completion through Carapace;
- rounded structured tables and adaptive wide-output rendering;
- clickable links and modern shell integration escape sequences;
- `glog` for structured Git history;
- `nixsearch` for structured nixpkgs results;
- nearest-flake `ncheck`, `ndev`, `hmb`, and `hms` helpers;
- passive and active authorized-lab reconnaissance pipelines;
- JSON-producing JWT, Tor, hash, and Niri window helpers.

## Kitty: The Workstation Control Surface

Kitty is configured as the default terminal with:

- native Wayland rendering;
- JetBrains Mono Nerd Font at 14pt;
- Catppuccin colors, 92% opacity, hidden decorations, and rounded powerline
  tabs;
- 100,000 lines of scrollback viewed through Bat;
- clipboard, hyperlink, and URL detection;
- remote control over `unix:@kitty-aegis`;
- horizontal and vertical splits;
- path, URL, hash, and line hint kittens;
- broadcast input;
- safe prompt-aware paste handling;
- quick windows for Btop, Yazi, Lazygit, Neovim, and tmux.

Framework-aware tabs are built in:

| Command | Action |
|---|---|
| `ka` | Open Kitty at the framework root |
| `kdev` | Open a tab in `nix develop` |
| `kcheck` | Open a tab running the Home Manager build |
| `kitty-framework switch` | Open a tab running the Home Manager switch |

The matching keyboard shortcuts use `Ctrl+Shift+Alt+R`, `D`, `C`, and `S`.

On generic Linux, WHOcares! prefers a distro-managed `/usr/bin/kitty` when it is
available and falls back to the pinned nixpkgs Kitty package. On NixOS it uses
the pinned nixpkgs package directly.

## tmux: Persistent Sessions and Instant Scratchpads

tmux uses `Ctrl+Space` as its prefix, vi keys, mouse support, true color,
Kitty passthrough, top-positioned status, and 100,000 lines of history.

### tmux plugins

- `sensible`
- `yank`
- `resurrect`
- `continuum`
- `copycat`
- `open`
- `vim-tmux-navigator`
- `extrakto`
- `mode-indicator`
- `prefix-highlight`
- `tmux-fzf`
- `tmux-sessionx`
- `pain-control`
- `tmux-thumbs`

Continuum saves every five minutes and restores on boot. A user service starts
the persistent `main` session at graphical login.

Custom scratchpads are a defining feature:

| Key | Action |
|---|---|
| `Alt+\`` | Toggle an 88x72% popup shell |
| `Alt+Shift+\`` | Toggle a 96x92% popup shell |
| `Ctrl+Space \`` | Toggle a persistent scratch window |
| `tm` | Attach to or create the `main` session |

## Neovim: Reproducible Operator IDE

Neovim is fully Nix-managed. It does not use Mason or runtime parser downloads;
language servers, formatters, linters, plugins, and Treesitter grammars all
come from the pinned package set.

### Editor plugins

| Area | Plugins |
|---|---|
| Theme and UI | Catppuccin, Lualine, Bufferline, Which Key, Web Devicons, Indent Blankline |
| Search and navigation | Telescope, Telescope fzf-native, fzf-lua, Flash, Harpoon, Oil |
| Git | Gitsigns, Fugitive, Diffview |
| Editing | Comment, Substitute, Mini, Autopairs, Undotree |
| Diagnostics | Trouble, Todo Comments, Fidget, `nvim-lint` |
| Terminals | Toggleterm |
| Notes | Render Markdown |
| Language support | native LSP config, Blink completion, LSPKind, Conform |

### Language support

| Language | Server or tooling |
|---|---|
| Nix | `nixd`, Alejandra, Statix, Deadnix |
| Lua | `lua-language-server`, StyLua |
| Bash/Zsh | `bash-language-server`, `shfmt`, ShellCheck |
| Markdown | Marksman |
| YAML | `yaml-language-server` |
| Python | Pyright and Ruff |
| TOML | Taplo |

Formatting runs on save, diagnostics are sorted by severity, completion uses
LSP/path/buffer sources, and `nixd` evaluates options against this exact flake.

Framework keybindings include:

- `<leader>nf` and `<leader>ng` for framework file and text search;
- `<leader>nd` for `nix develop`;
- `<leader>nc` for flake checking;
- `<leader>nb` for a Home Manager build;
- `<leader>ns` for a Home Manager switch;
- `<leader>gd`, `<leader>gh`, and `<leader>gq` for Diffview;
- `<leader>tt`, `<leader>tb`, and `<leader>ty` for Lazygit, Btop, and Yazi.

## Git, SSH, GPG, and Secrets

Git defaults to `main`, rebases pulls, auto-stashes during rebase, uses diff3
conflicts, and sends diffs through Delta. Delta adds syntax highlighting,
line numbers, navigation, and side-by-side views.

SSH automatically offers the Ed25519 identity, keeps connections alive, and
adds keys to the agent.

GPG uses the agent with SSH support, strong cipher and digest preferences,
SHA-512 certificates, disabled symmetric-key caching, and hidden recipient key
IDs. The workstation also includes Age, SOPS, Bitwarden CLI, and KeePassXC.

## Dolphin: Graphical Files Meet Terminal Workflows

Dolphin is the default directory handler and includes:

- archive browsing through Ark;
- KIO extras, FUSE, and `admin:/` support;
- image, video, and Git-aware plugins;
- hidden files, full paths, tooltips, previews, and zoom controls;
- a custom **WHOcares!** context menu.

The context menu can open a selected directory in Kitty, edit a selection in
Neovim, or find the nearest flake and enter its development shell.

Shell shortcuts are `fm`, `fmh`, and `fma`.

## Media: One Configuration for CLI and GUI

Celluloid is the graphical default for common audio and video formats, while
MPV provides the underlying playback configuration.

MPV customizations include:

- Wayland `gpu-next` rendering and safe hardware decoding;
- high-quality Lanczos/Mitchell scaling and debanding;
- watch-later position persistence;
- `yt-dlp` quality selection;
- large forward and backward caches;
- UOSC controls;
- Thumbfast previews;
- MPRIS desktop integration;
- SponsorBlock categories;
- automatic playlist loading;
- screenshots into the XDG pictures directory.

Installed MPV scripts are `autoload`, `memo`, `mpris`, `quality-menu`,
`sponsorblock`, `thumbfast`, and `uosc`.

The `queue` command creates a persistent MPV IPC session and appends files or
URLs to it. `media-clear` clears the queue and `now` reports status through
MPRIS.

## Nix Operations and Awesome-List Tooling

WHOcares! wraps common maintenance operations with low-priority, resource-aware
commands:

| Command | Purpose |
|---|---|
| `hm-check` | Build the active Home Manager profile |
| `hm` | Switch the active Home Manager profile |
| `nix-audit` | Run Deadnix and Statix |
| `nix-fmt` | Format Nix with Alejandra |
| `nix-health` | Show Nix version, outputs, and build health |
| `nix-up` | Update locked inputs |
| `nix-gc` | Delete old generations and collect garbage |
| `whocares` / `aegis` | Rebuild the selected NixOS host |

The Awesome-list module adds package discovery, option search, derivation
inspection, flake-lock browsing, update helpers, local nixpkgs PR review,
ephemeral VMs, NixOS containers, and Nix-driven Compose.

Notable tools include:

- Nix: `nh`, `nom`, `nix-tree`, `nvd`, `manix`, `comma`, `nix-du`,
  `nix-melt`, `dix`, `nurl`, `optnix`, `vulnix`, `nix-fast-build`,
  `colmena`, and `deploy-rs`;
- workflow: Pueue, Mprocs, Sad, Jqp, Viddy, Entr, CSVLens, Gum, Watchexec,
  Television, and Just;
- containers: Podman, Buildah, Skopeo, Dive, Distrobox, Lazydocker, Nerdctl,
  runc, Youki, Arion, and `extra-container`;
- data and networking: `fq`, `fx`, `jc`, Miller, Dasel, Gron, Doggo, MTR,
  Trippy, HTTPie, Curlie, and Xh.

Pueue runs as a managed user service. The first Home Manager activation can
build a local `nix-index` database so `comma` and `nix-locate` work offline.

## Security Workstation Features

The base profile includes a broad authorized-lab and defensive toolset:

- privacy: Tor Browser, Torsocks, ProxyChains, I2P, WireGuard, Firejail, and
  MACChanger;
- discovery: Subfinder, Amass, HTTPX, theHarvester, Recon-ng, Nmap, Masscan,
  RustScan, Nuclei, FFUF, Gobuster, Feroxbuster, and DNS tools;
- web assessment: SQLMap, Burp Suite, and mitmproxy;
- credential auditing: John, Hashcat, Hashcat Utils, and SecLists;
- directory services and post-exploitation labs: Metasploit, BloodHound,
  Neo4j, and Evil-WinRM;
- traffic and wireless analysis: Ettercap, Bettercap, Responder, Aircrack-ng,
  hcxdumptool, hcxtools, Kismet, and Horst;
- hardware: Flashrom, OpenOCD, Sigrok, PulseView, Minicom, Picocom, and SDCC;
- forensics and reverse engineering: Volatility, Sleuth Kit, ExifTool,
  Stegseek, Foremost, Scalpel, Radare2, Rizin, Cutter, Ghidra, GDB, Capstone,
  Keystone, and pwntools.

Use assessment tools only on systems, networks, and accounts you own or are
explicitly authorized to test.

### Optional defensive security extension

`home/modules/security.nix` is imported but `whycare.security.enable` is off by
default. Enabling it adds:

- secret scanning with Gitleaks, TruffleHog, and Git Secrets;
- supply-chain checks with OSV Scanner, Vulnix, and optional Trivy, Grype, and
  Syft;
- code checks with ShellCheck, Hadolint, and optional Semgrep;
- local network baselining;
- `security-check`, which combines the checks with a flake evaluation;
- manually synchronized security reference repositories;
- an optional deep DFIR/scanning package set.

The reference repositories are reading material and are never executed or
cloned during Home Manager activation.

## Whonix: Guarded Privacy VM Management

The `whonix` controller manages the official Gateway and Workstation through
the system libvirt connection.

It provides:

- host readiness checks for KVM, libvirt, domains, and networks;
- host setup for libvirt and virtualization groups;
- signature and documented fingerprint verification in a temporary GnuPG
  home;
- sparse extraction of official KVM archives;
- license-marker enforcement before import;
- upstream-owned domain and network XML import;
- dependency-aware start, stop, restart, and force-stop ordering;
- status, interface, graphical viewer, and serial console commands;
- compatibility with official and legacy local domain names.

The signing fingerprint is checked against
`916B 8D99 C38E AF5E 8ADC 7A2A 8D66 066A 2EEA CCDA`.

Useful aliases include `wx`, `wxs`, `wxd`, `wxsetup`, `wxverify`, `wxextract`,
`wximport`, `wxv`, `wxvg`, `wxstop`, `wxrestart`, `wxconsole`, and `wxnet`.

WHOcares! deliberately does not download Whonix images or accept its binary
license automatically.

## External Knowledge Repositories

The external-repository module can manually synchronize selected projects and
Awesome lists into `~/.local/share/whocares/repos`.

It includes references for Nix, Zsh plugins, CLI apps, Linux containers,
cheatsheets, GitHub resources, CodeCompanion, Cloak Browser, Sheldon,
Liquidprompt, and other experiments.

Nothing is cloned during shell startup or Home Manager activation.

```sh
repos             # clone or fast-forward configured references
repo-list         # list local references
awsrc nix         # read the local Awesome Nix README
awsrc zsh         # read the local Awesome Zsh Plugins README
awsrc cli         # read the local Awesome CLI Apps README
awsrc containers  # read the local Awesome Linux Containers README
```

## Optional Profiles

The `whycare.profiles` namespace keeps heavyweight additions opt-in:

| Switch | Adds |
|---|---|
| `full.enable` | Every optional package group |
| `graphics.enable` | Inkscape, GIMP, ImageMagick, and Blender |
| `office.enable` | LibreOffice and Thunderbird |
| `vms.enable` | QEMU/KVM, Virt Manager, Virt Viewer, libvirt, swtpm, Distrobox, Lazydocker, and Nerdctl |
| `rocm.enable` | `clinfo` and `rocminfo` |
| `browser` | Brave or Firefox package selection |

The active profile currently uses Brave and leaves the heavyweight groups
disabled.

## Desktop and NixOS Extension Scaffolding

`home/modules/desktop.nix` contains a Niri and DankMaterialShell integration
with dynamic theming, monitoring, VPN, audio visualization, calendar,
clipboard history, idle handling, and Qutebrowser support. It is part of the
active Home Manager import list. Nix seeds the DMS session and settings only
when missing, then leaves the files mutable so DMS can manage its own settings
from the running shell.

The experimental NixOS constructor already knows how to compose:

- Disko;
- Impermanence;
- SOPS Nix;
- Niri;
- Hyprland;
- Lanzaboote;
- Comin;
- MicroVM;
- Catppuccin;
- Stylix;
- Home Manager;
- the shared nix-index database.

The `Aegis-Dualis` host enables libvirt and Virt Manager, but its root
filesystem is still a temporary `tmpfs` placeholder. Add real hardware, boot,
and disk configuration before using it for installation.

## Generated References

Home Manager writes local quick references under the XDG data directory for:

- Kitty;
- tmux;
- the Awesome-list toolchain;
- the optional defensive security suite.

These references travel with the configuration and stay synchronized with the
commands that generate them.

## Daily Survival Guide

```sh
# Inspect without changing the machine
nix run .
nix develop
nix flake check --no-build --show-trace

# Build, then activate
hm-check
hm

# Build, then activate through flake apps
nix run .#home-build
nix run .#home-switch

# Maintain quality
nix-audit
nix-fmt
nix-health
nix build .#checks.x86_64-linux.source-quality --no-link

# Discover what is available
awesome
tcheck
zpl

# Open the framework
dots
ka
```

Activation notes:

- Start a fresh shell or run `exec zsh` after Home Manager switches shell files.
- Plasma wallpaper apply errors are non-fatal on Niri or non-Plasma sessions.
- Non-NixOS GPU setup warnings are informational until a Nix-built GUI app needs
  host GPU driver integration.
- If a Nix command cannot reach `/nix/var/nix/daemon-socket/socket`, run it
  outside the restricted sandbox or fix Nix daemon access on that host.

That is what makes WHOcares! compelling: the shell, editor, terminal,
multiplexer, file manager, media stack, security tools, VM workflows, and Nix
operations are not isolated customizations. They are one reproducible system
with shared themes, shared paths, shared commands, pinned plugins, and
deliberate escape hatches for optional or host-specific features.
