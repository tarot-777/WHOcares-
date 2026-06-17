{
  inputs,
  settings,
}: let
  inherit (inputs.nixpkgs) lib;

  nixpkgsConfig = {
    allowUnfree = true;
    rocmSupport = false;
    permittedInsecurePackages = [];
  };

  overlays = [
    inputs.fenix.overlays.default
    inputs.nix-alien.overlays.default
  ];

  mkPkgs = system:
    import inputs.nixpkgs {
      inherit system overlays;
      config = nixpkgsConfig;
    };

  commonSpecialArgs = {
    inherit inputs;
    flakeRoot = settings.repositoryPath;
    userName = settings.user.name;
    userEmail = settings.user.email;
    homeDirectory = settings.user.homeDirectory;
    nixosHostName = settings.defaultNixosHost;
  };

  homeSharedModules = [
    inputs.catppuccin.homeModules.catppuccin
    inputs.stylix.homeModules.stylix
    inputs.nix-index-database.homeModules.nix-index
  ];

  embeddedHomeSharedModules =
    homeSharedModules
    ++ [
      {
        nixpkgs = {
          config = nixpkgsConfig;
          inherit overlays;
        };
      }
    ];

  mkHome = {
    hostName,
    system ? settings.defaultSystem,
    genericLinux ? false,
    extraModules ? [],
  }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
      extraSpecialArgs =
        commonSpecialArgs
        // {
          inherit hostName;
          isNixOS = !genericLinux;
        };
      modules =
        homeSharedModules
        ++ [../home/malachi]
        ++ lib.optional genericLinux {
          targets.genericLinux.enable = true;
        }
        ++ extraModules;
    };

  nixosIntegrationModules = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    inputs.niri-flake.nixosModules.niri
    inputs.hyprland.nixosModules.default
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.comin.nixosModules.comin
    inputs.microvm.nixosModules.host
    inputs.catppuccin.nixosModules.catppuccin
    inputs.stylix.nixosModules.stylix
    inputs.nix-index-database.nixosModules.nix-index
  ];

  mkNixos = {
    hostName,
    system ? settings.defaultSystem,
    modules ? [],
  }:
    lib.nixosSystem {
      inherit system;
      specialArgs =
        commonSpecialArgs
        // {
          inherit hostName;
          isNixOS = true;
        };
      modules =
        [
          {
            nixpkgs.pkgs = mkPkgs system;
            catppuccin = {
              enable = false;
              autoEnable = false;
            };
          }
        ]
        ++ nixosIntegrationModules
        ++ modules
        ++ [
          {
            home-manager = {
              useGlobalPkgs = false;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              sharedModules = embeddedHomeSharedModules;
              extraSpecialArgs =
                commonSpecialArgs
                // {
                  inherit hostName;
                  isNixOS = true;
                };
              users.${settings.user.name} = import ../home/malachi;
            };
          }
        ];
    };

  homeConfigurations =
    lib.mapAttrs' (
      hostName: profile:
        lib.nameValuePair "${settings.user.name}@${hostName}" (mkHome ({
            inherit hostName;
          }
          // profile))
    )
    settings.homeProfiles;

  nixosConfigurations =
    lib.mapAttrs (
      hostName: host:
        mkNixos (host // {inherit hostName;})
    )
    settings.nixosHosts;
in {
  inherit
    commonSpecialArgs
    homeConfigurations
    homeSharedModules
    mkHome
    mkNixos
    mkPkgs
    nixosConfigurations
    nixpkgsConfig
    overlays
    ;
}
