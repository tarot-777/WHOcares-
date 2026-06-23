# ---------------------------------------------------------------------------
# reference-repos.nix — Unified WHOcares! repository synchronization engine
#
# Consolidates security and general reference lists. Implements strict,
# fault-tolerant synchronization logic to prevent pipeline collapse from
# upstream force-pushes or divergent histories.
# ---------------------------------------------------------------------------
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.externalRepos;

  baseRoot = "${config.home.homeDirectory}/.local/share/whocares";
  generalRoot = "${baseRoot}/repos";
  securityRoot = "${baseRoot}/security-repos";

  generalRepos = {
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

  securityRepos = {
    awesome-security = "https://github.com/sbilly/awesome-security.git";
    awesome-hacking = "https://github.com/Hack-with-Github/Awesome-Hacking.git";
    awesome-osint = "https://github.com/jivoi/awesome-osint.git";
    awesome-pentest = "https://github.com/enaqx/awesome-pentest.git";
    awesome-web-security = "https://github.com/qazbnm456/awesome-web-security.git";
    awesome-incident-response = "https://github.com/meirwah/awesome-incident-response.git";
    awesome-threat-intelligence = "https://github.com/hslatman/awesome-threat-intelligence.git";
    awesome-security-hardening = "https://github.com/decalage2/awesome-security-hardening.git";
    awesome-devsecops = "https://github.com/devsecops/awesome-devsecops.git";
    awesome-yara = "https://github.com/InQuest/awesome-yara.git";
  };

  # Generates a fault-tolerant sync block for a specific repository.
  mkSyncBlock = name: url: targetDir: ''
    if [ -d "${targetDir}/${name}/.git" ]; then
      echo "[syncing] ${name}"
      ${pkgs.git}/bin/git -C "${targetDir}/${name}" fetch --depth 1 origin || true
      ${pkgs.git}/bin/git -C "${targetDir}/${name}" reset --hard origin/HEAD || true
      ${pkgs.git}/bin/git -C "${targetDir}/${name}" clean -fd || true
    else
      echo "[cloning] ${name}"
      ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none "${url}" "${targetDir}/${name}" || true
    fi
  '';

  generalSyncBody = concatStringsSep "\n" (mapAttrsToList (name: url: mkSyncBlock name url generalRoot) generalRepos);
  securitySyncBody = concatStringsSep "\n" (mapAttrsToList (name: url: mkSyncBlock name url securityRoot) securityRepos);

  whocaresSyncAll = pkgs.writeShellScriptBin "whocares-sync-all" ''
    set -euo pipefail
    echo "Initializing WHOcares repository synchronization..."
    ${pkgs.coreutils}/bin/mkdir -p "${generalRoot}" "${securityRoot}"

    echo "--- General Repositories ---"
    ${generalSyncBody}

    echo "--- Security Repositories ---"
    ${securitySyncBody}

    echo "Synchronization complete."
  '';

  pkg = name: attrByPath [name] null pkgs;
  present = names: builtins.filter (package: package != null) (map pkg names);

  baseSecurityTools = present [
    "age"
    "rage"
    "sops"
    "gnupg"
    "minisign"
    "cosign"
    "gitleaks"
    "trufflehog"
    "git-secrets"
    "osv-scanner"
    "vulnix"
    "shellcheck"
    "shfmt"
    "hadolint"
    "nmap"
    "tcpdump"
    "termshark"
    "whois"
    "dnsutils"
    "sslscan"
  ];

  deepSecurityTools = present [
    "semgrep"
    "trivy"
    "grype"
    "syft"
    "yara"
    "clamav"
    "binwalk"
    "foremost"
    "sleuthkit"
    "hashdeep"
    "lynis"
    "rkhunter"
    "rustscan"
    "testssl"
    "wireshark-cli"
  ];
in {
  options.whycare.externalRepos = {
    enable = mkEnableOption "WHOcares unified reference repository engine";
    deepSecurity.enable = mkEnableOption "Heavy DFIR and vulnerability scanning tools";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [
        git
        fzf
        ripgrep
        jq
        curl
        file
        sheldon
        liquidprompt
        whocaresSyncAll
      ]
      ++ baseSecurityTools ++ optionals cfg.deepSecurity.enable deepSecurityTools;

    home.sessionVariables = {
      WHOCARES_REPOS = generalRoot;
      WHOCARES_SECURITY_REPOS = securityRoot;
    };

    programs.zsh.shellAliases = {
      sync-repos = "whocares-sync-all";
      awsrc = "cd ${generalRoot}";
      secsrc = "cd ${securityRoot}";
    };

    programs.nushell.extraConfig = ''
      alias sync-repos = whocares-sync-all
      alias awsrc = cd ${generalRoot}
      alias secsrc = cd ${securityRoot}
    '';
  };
}
