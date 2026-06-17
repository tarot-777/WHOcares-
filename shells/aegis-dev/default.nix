{pkgs}:
pkgs.mkShell {
  packages = with pkgs; [
    git
    nh
    home-manager
    nix-output-monitor
    alejandra
    statix
    deadnix
    nil
    nixd
    ripgrep
  ];

  shellHook = ''
    echo "WHOcares dev shell"
    echo "nix flake check --no-build --show-trace"
    echo "nix run .#home-build"
    echo "nix run .#home-switch"
  '';
}
