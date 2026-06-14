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
nh home build . -c malachi@coffin
```

## Scope

- Put user and host identity in `settings.nix`.
- Keep Home Manager features in focused files under `home/modules/`.
- Keep NixOS-only behavior under `hosts/`.
- Do not download shell plugins or mutable dependencies during activation.
- Do not add secrets, VM images, archives, or machine-specific credentials.
- Preserve explicit verification and license acceptance in privacy workflows.

## Commit Notes

Describe the behavior changed and the validation performed. Call out changes
that require a new login session, host-level privileges, or manual migration.
