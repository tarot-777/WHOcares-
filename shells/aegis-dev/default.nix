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
    echo "nh home build . -c malachi@coffin"
    echo "nh home switch . -c malachi@coffin"
  '';
}
