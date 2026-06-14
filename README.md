# WHOcares! Nix Framework

WHOcares! is a flake-based Home Manager environment for `malachi@coffin`
(generic Linux) plus an experimental `Aegis-Dualis` NixOS host output. It
combines a power-user Zsh setup, curated Awesome-list tools, security and
development packages, and libvirt helpers for a Whonix Gateway/Workstation
pair.

Repository: <https://github.com/tarot-777/WHOcares->

## Current Targets

| Target | Output | Status |
|---|---|---|
| Generic Linux | `homeConfigurations."malachi@coffin"` | Default and actively switched |
| NixOS Home Manager | `homeConfigurations."malachi@Aegis-Dualis"` | Evaluated profile |
| NixOS host | `nixosConfigurations.Aegis-Dualis` | Host scaffold; adapt boot and filesystem settings before installation |

The repository is expected at `/home/malachi/WHOcares!`, as configured in
`settings.nix`. Override commands with `AEGIS_FLAKE` or `WHOCARES_FLAKE` when
using another path.

## Quick Start

From the flake root:

```sh
nix flake check --no-build --show-trace
nh home build . -c malachi@coffin
nh home switch . -c malachi@coffin
```

After the first switch, the shorter wrappers are available:

```sh
hm-check       # low-priority Home Manager build
hm             # low-priority Home Manager switch
nix-audit      # deadnix + statix
nix-fmt        # format Nix files with alejandra
nix-up         # update flake.lock
nix-health     # versions, outputs, and Home Manager build
```

Use `-c` for Home Manager configurations and `-H` for NixOS hosts. Do not pass
`.#malachi@coffin` as the flake path to `nh`.

## Zsh And Plugins

Home Manager owns the Zsh configuration and all plugin source paths. Shell
startup never clones repositories or downloads plugins.

Managed plugins:

- `fzf-tab`: context-aware completion previews
- `zsh-vi-mode`: full vi editing with `jk` to leave insert mode
- `zsh-autopair`: paired quotes, brackets, and braces
- `zsh-you-should-use`: reminders when an existing alias matches a command
- Home Manager integrations: autosuggestions, syntax highlighting, Atuin,
  Carapace, fzf, Starship, Zoxide, direnv, and Yazi

Plugin commands:

```sh
zpl            # display plugin names and pinned versions
zpr            # reload Zsh
zpu            # update flake inputs, then run hm
```

Plugin versions follow the pinned `nixpkgs` input. Review `flake.lock`, run
`nix-up`, then activate with `hm`.

## Useful Shell Commands

The configuration includes modern replacements (`eza`, `bat`, `fd`, `rg`,
`dust`, `duf`, `procs`, `btop`) and focused shortcuts:

| Area | Commands |
|---|---|
| Navigation | `..`, `...`, `....`, `dots`, `mkcd`, `cdf`, `z`, `yy` |
| Git | `g`, `gs`, `ga`, `gaa`, `gc`, `gco`, `gd`, `gds`, `gl`, `gp`, `gpl`, `lg`, `git-root` |
| Nix | `nd`, `nfl`, `nr`, `ns`, `nshow`, `hm`, `hm-check`, `nfind`, `nopt`, `nlock`, `ndix` |
| Data and logic | `jqx`, `csv`, `sr`, `fq`, `dasel`, `miller`, `choose` |
| Process workflow | `pq`, `mp`, `watch`, `fkill`, `entr`, `watchexec` |
| Network and privacy | `ports`, `listening`, `netmon`, `px`, `torify`, `tor-status` |
| Containers | `dk`, `dkc`, `dkps`, `dbx`, `lzd`, `nctr`, `ncompose` |
| General | `extract`, `serve`, `cs`, `nav`, `md`, `tcheck`, `awesome` |

Run `awesome-list` for the live inventory and `tools-check` to audit command
availability.

## Awesome-List Integration

`home/modules/awesome-tools.nix` maps a curated selection from Awesome Nix,
Awesome CLI Apps, and Awesome Linux Containers into nixpkgs. Notable workflow
tools include:

- `pueue`: persistent background command queue (`pq`)
- `mprocs`: monitor several long-running commands (`mp`)
- `sad`: preview search-and-replace operations (`sr`)
- `jqp`: interactive jq exploration (`jqx`)
- `viddy`: watch output with history and diffs (`watch`)
- `entr`: rerun a command when files change
- `csvlens`: interactive CSV inspection (`csv`)
- `gum`: readable interactive shell workflows

Reference repositories are optional and are not cloned during activation:

```sh
repos                         # clone/update configured references
repo-list                     # list cloned references
awsrc nix                     # Awesome Nix README
awsrc zsh                     # Awesome Zsh Plugins README
awsrc cli                     # Awesome CLI Apps README
awsrc containers              # Awesome Linux Containers README
```

They live under `~/.local/share/whocares/repos`.

## Whonix

The Home Manager profile installs a `whonix` controller for the libvirt system
connection (`qemu:///system`) and provides these aliases:

| Alias | Action |
|---|---|
| `wx` | Start Gateway, wait briefly, then start Workstation |
| `wxs` | Show both VM states and interfaces |
| `wxv` / `wxvg` | Open the Workstation / Gateway in `virt-viewer` |
| `wxstop` | Gracefully stop Workstation, then Gateway |
| `wxrestart` | Stop and restart both in dependency order |
| `wxconsole` / `wxgw` | Open Workstation / Gateway serial console |
| `wxnet` | Show Workstation interfaces |

The full command also supports `whonix force-stop`, `whonix network`, and
`whonix provision`. Run `whonix help` for details.

The NixOS host module expects:

```text
/var/lib/libvirt/images/whonix-gw.qcow2
/var/lib/libvirt/images/whonix-ws.qcow2
```

Download the official KVM images from <https://www.whonix.org/wiki/KVM> and
verify their signatures before installation. The host module creates an
isolated `virbr-whonix` bridge, defines both domains, and enables Gateway
autostart. The Workstation has only the isolated NIC and reaches the network
through the Gateway.

On generic Linux, the aliases are available but the domains and bridge must
already exist in system libvirt.

## Feature Profiles

Edit `home/malachi/default.nix`:

```nix
whycare = {
  enableFullPower = false;
  shell.enable = true;
  externalRepos.enable = true;

  profiles = {
    full.enable = false;
    graphics.enable = false;
    office.enable = false;
    vms.enable = false;
    rocm.enable = false;
    browser = "brave"; # or "firefox"
  };
};
```

The base profile already contains a substantial security and development
toolchain. Optional profiles add graphics, office, VM, or ROCm packages.

## Development And Validation

```sh
nix develop .#aegis-dev
nix fmt
statix check .
deadnix .
nix flake check --no-build --show-trace
```

The dev shell includes `nh`, Home Manager, Alejandra, Statix, Deadnix, `nil`,
`nixd`, and `ripgrep`.

## Layout

```text
.
├── flake.nix
├── flake.lock
├── settings.nix
├── lib/framework.nix
├── home/
│   ├── malachi/default.nix
│   └── modules/
│       ├── awesome-tools.nix
│       ├── external-repos.nix
│       ├── profiles.nix
│       ├── shell.nix
│       ├── whonix.nix
│       └── zsh.nix
├── hosts/aegis-dualis/
│   ├── default.nix
│   └── whonix-vms.nix
└── shells/aegis-dev/default.nix
```

## Troubleshooting

- `path does not contain a flake.nix`: run commands from the repository root
  or pass `/home/malachi/WHOcares!`.
- Missing Home Manager configuration: use
  `nh home switch . -c malachi@coffin`.
- Whonix domain undefined: install the images and apply the NixOS host module,
  or define equivalent domains in system libvirt.
- Permission denied for `qemu:///system`: add the user to the host's `libvirt`
  group and start a new login session.
- First activation may build the local `nix-index` database and can take
  longer than later switches.
