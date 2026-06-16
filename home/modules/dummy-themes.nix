{ lib, pkgs, ... }:
{
  options.catppuccin = lib.mkOption {
    type = lib.types.attrs; # accept any attrs
    default = {};
    description = "Placeholder catppuccin options for evaluation";
  };

  options.stylix = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Placeholder stylix options for evaluation";
  };
}
