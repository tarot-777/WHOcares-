{
  description = "WHOcares! - a flake-powered Linux workstation framework";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
      "https://hyprland.cachix.org"
      "https://microvm.cachix.org"
      "https://numtide.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSeBc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland.git?ref=refs/tags/v0.47.0&submodules=1";

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;
    settings = import ./settings.nix;
    framework = import ./lib/framework.nix {inherit inputs settings;};
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = settings.supportedSystems;

      perSystem = {system, ...}: let
        pkgs = framework.mkPkgs system;
        defaultRoot = self.outPath;
        defaultHomeProfile = "${settings.user.name}@${settings.defaultHomeHost}";
        runtimeFlakeRef = ''
          root="''${WHOCARES_FLAKE:-}"
          if [[ -z "$root" ]]; then
            root="''${AEGIS_FLAKE:-}"
          fi
          if [[ -z "$root" ]]; then
            if [[ -f "${settings.repositoryPath}/flake.nix" ]]; then
              root="${settings.repositoryPath}"
            elif [[ -f "$PWD/flake.nix" ]]; then
              root="$PWD"
            else
              root="${defaultRoot}"
            fi
          fi
          case "$root" in
            *:*) flake_ref="$root" ;;
            *) flake_ref="path:$root" ;;
          esac
        '';

        mkCommand = {
          name,
          runtimeInputs,
          text,
        }:
          pkgs.writeShellApplication {
            inherit name runtimeInputs text;
          };

        formatter = mkCommand {
          name = "whocares-fmt";
          runtimeInputs = [pkgs.alejandra];
          text = ''
            if (($# == 0)); then
              set -- .
            fi
            exec alejandra "$@"
          '';
        };

        pipelineText =
          builtins.replaceStrings
          [
            "__WHOCARES_DEFAULT_FLAKE__"
            "__WHOCARES_DEFAULT_USER__"
            "__WHOCARES_DEFAULT_HOME_HOST__"
            "__WHOCARES_DEFAULT_NIXOS_HOST__"
            "__WHOCARES_DEFAULT_SYSTEM__"
          ]
          [
            settings.repositoryPath
            settings.user.name
            settings.defaultHomeHost
            settings.defaultNixosHost
            settings.defaultSystem
          ]
          (builtins.readFile ./scripts/whocares-pipeline.sh);

        commands = rec {
          info = mkCommand {
            name = "aegis-info";
            runtimeInputs = [pkgs.nix];
            text = ''
              ${runtimeFlakeRef}
              printf '%s\n' \
                "WHOcares! workstation framework" \
                "Declarative shell, editor, desktop, media, and privacy workflows." \
                "" \
                "Root:          $root" \
                "Flake ref:     $flake_ref" \
                "Home profile:  ${defaultHomeProfile}" \
                "Workstation:   ${settings.user.name}@workstation" \
                "Laptop:        ${settings.user.name}@laptop / ${settings.user.name}@hp-laptop" \
                "NixOS host:    ${settings.defaultNixosHost}" \
                "Portable OS:   workstation / laptop / hp-laptop" \
                "" \
                "Capabilities:" \
                "  Home Manager     Zsh, Nushell, Neovim, Kitty, tmux, Git, and CLI tools" \
                "  Desktop          Niri-oriented Wayland tools, Dolphin, and media defaults" \
                "  Automation       Build, switch, update, audit, and health-check commands" \
                "  LLM workflows    Redacted context, fixpacks, review prompts, and guarded patches" \
                "  Privacy          Guarded Whonix verification, import, and libvirt control" \
                "  Profiles         Optional graphics, office, virtualization, and ROCm sets" \
                "" \
                "Try it:" \
                "  nix develop $flake_ref" \
                "  nix run $flake_ref#pipeline -- inputs" \
                "  nix run $flake_ref#pipeline -- validate" \
                "  nix run $flake_ref#home-build" \
                "  nix run $flake_ref#home-switch" \
                "  nix run $flake_ref#nixos-install -- <host> root@<target-ip>" \
                "  nix run $flake_ref#check"
            '';
          };

          pipeline = mkCommand {
            name = "whocares-pipeline";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.home-manager
              pkgs.nix
              pkgs.nixos-anywhere
              pkgs.nixos-rebuild
              pkgs.sudo
              pkgs.util-linux
            ];
            text = pipelineText;
          };

          home-build = mkCommand {
            name = "aegis-home-build";
            runtimeInputs = [pkgs.home-manager];
            text = ''
              ${runtimeFlakeRef}
              host="''${AEGIS_HOST:-${settings.defaultHomeHost}}"
              profile="''${AEGIS_PROFILE:-${settings.user.name}@$host}"
              [[ "$root" == *:* || -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec home-manager build --flake "$flake_ref#$profile" "$@"
            '';
          };

          home-switch = mkCommand {
            name = "aegis-home-switch";
            runtimeInputs = [pkgs.home-manager];
            text = ''
              ${runtimeFlakeRef}
              host="''${AEGIS_HOST:-${settings.defaultHomeHost}}"
              profile="''${AEGIS_PROFILE:-${settings.user.name}@$host}"
              [[ "$root" == *:* || -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec home-manager switch --flake "$flake_ref#$profile" "$@"
            '';
          };

          nixos-switch = mkCommand {
            name = "aegis-nixos-switch";
            runtimeInputs = [pkgs.nixos-rebuild pkgs.sudo];
            text = ''
              ${runtimeFlakeRef}
              host="''${AEGIS_NIXOS_HOST:-${settings.defaultNixosHost}}"
              [[ "$root" == *:* || -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec sudo nixos-rebuild switch --flake "$flake_ref#$host" "$@"
            '';
          };

          nixos-install = mkCommand {
            name = "aegis-nixos-install";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nixos-anywhere
              pkgs.util-linux
            ];
            text = ''
              usage() {
                cat >&2 <<'EOF'
              Usage: nix run <flake>#nixos-install -- <host> <ssh-target> [nixos-anywhere args...]

              Examples:
                nix run .#nixos-install -- laptop root@192.0.2.20 --vm-test
                nix run .#nixos-install -- workstation root@192.0.2.30

              Safety:
                Fresh installs require hosts/<host>/disko.nix so disk layout is explicit.
                Set WHOCARES_INSTALL_WITHOUT_DISKO=1 only for pre-mounted/custom nixos-anywhere phases.
              EOF
              }

              [[ $# -ge 2 ]] || {
                usage
                exit 2
              }

              ${runtimeFlakeRef}
              if [[ "$root" == *:* ]]; then
                echo "nixos-install requires a local flake path so host and disko files can be checked." >&2
                echo "Clone or copy the framework first, then run with WHOCARES_FLAKE=/path/to/WHOcares." >&2
                exit 2
              fi

              host="$1"
              target="$2"
              shift 2
              host_dir="$root/hosts/$host"

              [[ -d "$host_dir" ]] || {
                echo "nixos-install: unknown host '$host' at $host_dir" >&2
                exit 2
              }

              if [[ ! -f "$host_dir/disko.nix" && "''${WHOCARES_INSTALL_WITHOUT_DISKO:-0}" != "1" ]]; then
                echo "nixos-install: refusing install without $host_dir/disko.nix" >&2
                echo "Add an explicit disko layout first, or set WHOCARES_INSTALL_WITHOUT_DISKO=1 for custom phases." >&2
                exit 3
              fi

              exec nice -n "''${WHOCARES_NICE:-10}" \
                ionice -c2 -n7 \
                nixos-anywhere \
                  --flake "$flake_ref#$host" \
                  --option max-jobs "''${WHOCARES_NIX_JOBS:-1}" \
                  --option cores "''${WHOCARES_NIX_CORES:-2}" \
                  "$@" \
                  "$target"
            '';
          };

          check = mkCommand {
            name = "aegis-check";
            runtimeInputs = [pkgs.nix];
            text = ''
              ${runtimeFlakeRef}
              [[ "$root" == *:* || -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec nix flake check --no-build "$@" "$flake_ref"
            '';
          };

          update = mkCommand {
            name = "aegis-update";
            runtimeInputs = [pkgs.nix];
            text = ''
              ${runtimeFlakeRef}
              [[ "$root" == *:* || -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec nix flake update --flake "$flake_ref" "$@"
            '';
          };
        };

        commandDescriptions = {
          info = "Show WHOcares! capabilities, targets, and entry points";
          pipeline = "Run guided WHOcares bootstrap, validation, activation, and deployment workflows";
          home-build = "Build the selected Home Manager profile";
          home-switch = "Activate the selected Home Manager profile";
          nixos-switch = "Rebuild and activate the selected NixOS host";
          nixos-install = "Run guarded nixos-anywhere deployment for a local host";
          check = "Evaluate every flake output without building it";
          update = "Update the framework's locked flake inputs";
        };

        mkApp = name: package: {
          type = "app";
          program = lib.getExe package;
          meta.description = commandDescriptions.${name};
        };

        evaluation = {
          homeProfiles = builtins.attrNames settings.homeProfiles;
          nixosHosts = builtins.attrNames settings.nixosHosts;
          inherit defaultHomeProfile;
          inherit (settings) defaultNixosHost;
        };
      in {
        inherit formatter;

        devShells = {
          aegis-dev = import ./shells/aegis-dev {inherit pkgs;};
          default = self.devShells.${system}.aegis-dev;
        };

        packages =
          commands
          // {
            default = commands.info;
          };

        apps =
          lib.mapAttrs mkApp commands
          // {
            default = mkApp "info" commands.info;
          };

        checks = {
          devshell = self.devShells.${system}.aegis-dev;
          framework-evaluation =
            pkgs.writeText "aegis-framework-evaluation.json"
            (builtins.toJSON evaluation);
          source-quality =
            pkgs.runCommand "whocares-source-quality" {
              nativeBuildInputs = with pkgs; [
                alejandra
                deadnix
                shellcheck
                statix
              ];
              src = lib.cleanSource ./.;
            } ''
              cp -R "$src" source
              chmod -R u+w source
              cd source

              alejandra --check .
              statix check .
              deadnix --fail .
              shellcheck install.sh repair-from-documents-tree.sh scripts/whocares-pipeline.sh

              touch "$out"
            '';
        };
      };

      flake = {
        lib = {
          inherit settings;
          inherit
            (framework)
            mkHome
            mkNixos
            mkPkgs
            nixpkgsConfig
            ;
        };

        overlays.default = lib.composeManyExtensions framework.overlays;
        inherit
          (framework)
          homeConfigurations
          nixosConfigurations
          ;
      };
    };
}
