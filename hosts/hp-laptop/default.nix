{lib, ...}: {
  imports =
    [
      ../common/laptop.nix
    ]
    ++ lib.optional (builtins.pathExists ./disko.nix) ./disko.nix
    ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;
}
