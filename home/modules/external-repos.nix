{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.externalRepos;

  repoRoot = "${config.home.homeDirectory}/.local/share/whocares/repos";

  repos = {
    shin = "https://github.com/linuxmobile/shin.git";
    awesome-cheatsheets = "https://github.com/skywind3000/awesome-cheatsheets.git";
    CloakBrowser = "https://github.com/CloakHQ/CloakBrowser.git";
    sheldon = "https://github.com/rossmacarthur/sheldon.git";
    liquidprompt = "https://github.com/liquidprompt/liquidprompt.git";
    dorothy = "https://github.com/bevry/dorothy.git";
    awesome-github = "https://github.com/AntBranch/awesome-github.git";
    awesome-nix = "https://github.com/jhedev/awesome-nix.git";
    awesome-zsh-plugins = "https://github.com/unixorn/awesome-zsh-plugins.git";
    awesome-cli-apps = "https://github.com/agarrharr/awesome-cli-apps.git";
    awesome-linux-containers = "https://github.com/Friz-zy/awesome-linux-containers.git";
    FreeDomain = "https://github.com/DigitalPlatDev/FreeDomain.git";
    MasterDnsVPN = "https://github.com/masterking32/MasterDnsVPN.git";
    codecompanion-nvim = "https://github.com/olimorris/codecompanion.nvim.git";
  };

  repoList = lib.mapAttrsToList (name: url: "${name}|${url}") repos;

  whocaresRepos = pkgs.writeShellScriptBin "whocares-repos" ''
    set -euo pipefail
    root="${repoRoot}"
    mkdir -p "$root"

    if [ "''${1:-sync}" = "list" ]; then
      find "$root" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort
      exit 0
    fi

    ${lib.concatMapStringsSep "\n" (entry: let
        parts = lib.splitString "|" entry;
        name = lib.elemAt parts 0;
        url = lib.elemAt parts 1;
      in ''
        if [ -d "$root/${name}/.git" ]; then
          echo "[update] ${name}"
          git -C "$root/${name}" pull --ff-only || true
        else
          echo "[clone] ${name}"
          git clone --depth 1 "${url}" "$root/${name}" || true
        fi
      '')
      repoList}

    echo
    echo "Repos live in: $root"
  '';

  cheats = pkgs.writeShellScriptBin "cheats" ''
    set -euo pipefail
    root="${repoRoot}/awesome-cheatsheets"
    if [ ! -d "$root" ]; then
      echo "Run: whocares-repos"
      exit 1
    fi
    if [ "$#" -eq 0 ]; then
      find "$root" -type f | sed "s#$root/##" | sort | ${pkgs.fzf}/bin/fzf
    else
      rg -n "$*" "$root"
    fi
  '';

  awesomeNix = pkgs.writeShellScriptBin "awesome-nix-local" ''
    root="${repoRoot}/awesome-nix"
    [ -d "$root" ] || { echo "Run: whocares-repos"; exit 1; }
    ''${PAGER:-less} "$root/README.md"
  '';

  awesomeSources = pkgs.writeShellScriptBin "awesome-sources" ''
    set -euo pipefail
    case "''${1:-nix}" in
      nix) repo="awesome-nix" ;;
      zsh) repo="awesome-zsh-plugins" ;;
      cli) repo="awesome-cli-apps" ;;
      containers) repo="awesome-linux-containers" ;;
      *)
        echo "Usage: awesome-sources {nix|zsh|cli|containers}" >&2
        exit 2
        ;;
    esac
    readme="${repoRoot}/$repo/README.md"
    [ -f "$readme" ] || {
      echo "Reference repo is missing. Run: whocares-repos"
      exit 1
    }
    ''${PAGER:-less} "$readme"
  '';
in {
  options.whycare.externalRepos.enable =
    mkEnableOption "clone and expose selected external GitHub repositories";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      git
      fzf
      ripgrep
      sheldon
      liquidprompt
      whocaresRepos
      cheats
      awesomeNix
      awesomeSources
    ];

    programs.zsh.shellAliases = {
      repos = "whocares-repos";
      repo-list = "whocares-repos list";
      cheats-local = "cheats";
      awnix = "awesome-nix-local";
      awsrc = "awesome-sources";
    };

    home.sessionVariables = {
      WHOCARES_REPOS = repoRoot;
      AWESOME_CHEATSHEETS = "${repoRoot}/awesome-cheatsheets";
      AWESOME_NIX = "${repoRoot}/awesome-nix";
      CODECOMPANION_NVIM = "${repoRoot}/codecompanion-nvim";
      CLOAK_BROWSER = "${repoRoot}/CloakBrowser";
    };
  };
}
