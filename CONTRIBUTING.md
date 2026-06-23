# Contributing

WHOcares! is a personal workstation configuration with reusable framework
pieces. Changes should preserve the current host while keeping modules useful
to forks.

## Development

Enter the pinned toolchain:

```sh
nix develop
```

Before submitting a change:

```sh
nix fmt
nix flake check --show-trace
nix run .#home-build
```

For deployment-sensitive changes, also verify the bootstrap and app path:

```sh
tmpdir=$(mktemp -d)
./install.sh --target "$tmpdir/WHOcares" --home-host laptop --nixos-host laptop --skip-check
env -u AEGIS_FLAKE -u WHOCARES_FLAKE nix run "path:$tmpdir/WHOcares#info"
```

When you need the flake's source-quality derivation to actually run the tools,
use:

```sh
nix build .#checks.x86_64-linux.source-quality --no-link
```

## Scope

- Put user and host identity in `settings.nix`.
- Keep Home Manager features in focused files under `home/modules/`.
- Keep NixOS-only behavior under `hosts/`.
- Do not download shell plugins or mutable dependencies during activation.
- Do not add secrets, VM images, archives, or machine-specific credentials.
- Preserve explicit verification and license acceptance in privacy workflows.
- Keep `install.sh` portable and executable.
- Keep fresh NixOS installs guarded by explicit `hosts/<host>/disko.nix`.
- Keep machine-specific hardware files under `hosts/<host>/`.
- Prefer runtime overrides (`WHOCARES_FLAKE`, `WHOCARES_HOST`,
  `WHOCARES_PROFILE`, `WHOCARES_NIXOS_HOST`) over hardcoded paths in scripts.

## Activation Rules

- Build before switching: `nix run .#home-build`.
- Switch only when the user requested activation: `nix run .#home-switch`.
- On non-NixOS hosts, warnings about GPU setup or Plasma wallpaper application
  can be informational; do not paper over real activation failures.
- For NixOS switch paths, review boot, filesystem, user, and hardware settings
  before running `nix run .#nixos-switch`.
- For fresh installs, never run `nix run .#nixos-install` without an explicit
  target host, SSH target, hardware configuration, and `disko.nix`.

## Documentation

- `README.md` is the complete operator runbook.
- `HOWTOnotCRY.md` is the long-form architecture and survival reference.
- `SHELLS.md` lists aliases, wrappers, and shell behavior.
- `AGENT.md` gives automation agents the condensed runbook.
- Update the relevant Markdown file when a command name, target name, safety
  rule, or activation behavior changes.

## Commit Notes

Describe the behavior changed and the validation performed. Call out changes
that require a new login session, host-level privileges, or manual migration.
