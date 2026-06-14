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
        defaultHomeProfile = "${settings.user.name}@${settings.defaultHomeHost}";

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

        commands = rec {
          info = mkCommand {
            name = "aegis-info";
            runtimeInputs = [pkgs.nix];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              printf '%s\n' \
                "WHOcares! workstation framework" \
                "Declarative shell, editor, desktop, media, and privacy workflows." \
                "" \
                "Root:          $root" \
                "Home profile:  ${defaultHomeProfile}" \
                "NixOS host:    ${settings.defaultNixosHost}" \
                "" \
                "Capabilities:" \
                "  Home Manager     Zsh, Nushell, Neovim, Kitty, tmux, Git, and CLI tools" \
                "  Desktop          Niri-oriented Wayland tools, Dolphin, and media defaults" \
                "  Automation       Build, switch, update, audit, and health-check commands" \
                "  Privacy          Guarded Whonix verification, import, and libvirt control" \
                "  Profiles         Optional graphics, office, virtualization, and ROCm sets" \
                "" \
                "Try it:" \
                "  nix develop path:$root" \
                "  nix run path:$root#home-build" \
                "  nix run path:$root#home-switch" \
                "  nix run path:$root#check"
            '';
          };

          home-build = mkCommand {
            name = "aegis-home-build";
            runtimeInputs = [pkgs.home-manager];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              host="''${AEGIS_HOST:-${settings.defaultHomeHost}}"
              profile="''${AEGIS_PROFILE:-${settings.user.name}@$host}"
              [[ -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec home-manager build --flake "path:$root#$profile" "$@"
            '';
          };

          home-switch = mkCommand {
            name = "aegis-home-switch";
            runtimeInputs = [pkgs.home-manager];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              host="''${AEGIS_HOST:-${settings.defaultHomeHost}}"
              profile="''${AEGIS_PROFILE:-${settings.user.name}@$host}"
              [[ -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec home-manager switch --flake "path:$root#$profile" "$@"
            '';
          };

          nixos-switch = mkCommand {
            name = "aegis-nixos-switch";
            runtimeInputs = [pkgs.nixos-rebuild pkgs.sudo];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              host="''${AEGIS_NIXOS_HOST:-${settings.defaultNixosHost}}"
              [[ -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec sudo nixos-rebuild switch --flake "path:$root#$host" "$@"
            '';
          };

          check = mkCommand {
            name = "aegis-check";
            runtimeInputs = [pkgs.nix];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              [[ -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec nix flake check --no-build "$@" "path:$root"
            '';
          };

          update = mkCommand {
            name = "aegis-update";
            runtimeInputs = [pkgs.nix];
            text = ''
              root="''${AEGIS_FLAKE:-${settings.repositoryPath}}"
              [[ -f "$root/flake.nix" ]] || {
                echo "No flake.nix found at $root" >&2
                exit 2
              }
              exec nix flake update --flake "path:$root" "$@"
            '';
          };
        };

        commandDescriptions = {
          info = "Show WHOcares! capabilities, targets, and entry points";
          home-build = "Build the selected Home Manager profile";
          home-switch = "Activate the selected Home Manager profile";
          nixos-switch = "Rebuild and activate the selected NixOS host";
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
              shellcheck install.sh repair-from-documents-tree.sh

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
