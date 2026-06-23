{lib, ...}: {
  # Top-level placeholder for catppuccin namespace so nested options defined by
  # other modules (catppuccin.*) can exist. This is a lightweight submodule stub.
  options.catppuccin = lib.mkOption {
    type = lib.types.submodule;
    default = {};
    description = "Placeholder catppuccin namespace for evaluation";
  };

  # Stylix targets stub: modules check stylix.targets.gtk.enable etc. Use submodule so nested options allowed.
  # Individual target flags (provide defaults)
  options.stylix.targets.gtk.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Stub: stylix.targets.gtk.enable";
  };

  options.stylix.targets.mako.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Stub: stylix.targets.mako.enable";
  };

  options.stylix.targets.kitty.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Stub: stylix.targets.kitty.enable";
  };
}
