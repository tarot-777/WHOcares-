# ---------------------------------------------------------------------------
# security.nix — WHOcares! defensive security suite
#
# Pattern: use Awesome-list GitHub repositories as optional local reference
# material, while installing actual tools through pinned nixpkgs/Home Manager.
# Nothing is cloned during activation; run `security-repos` when you want the
# reference mirrors refreshed under ~/.local/share/whocares/security-repos.
# ---------------------------------------------------------------------------
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.security;

  repoRoot = "${config.home.homeDirectory}/.local/share/whocares/security-repos";

  repos = {
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

  repoNames = builtins.attrNames repos;

  repoSyncBody = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: url: ''
      if [ -d "$root/${name}/.git" ]; then
        echo "[update] ${name}"
        ${pkgs.git}/bin/git -C "$root/${name}" pull --ff-only || true
      else
        echo "[clone]  ${name}"
        ${pkgs.git}/bin/git clone --depth 1 --filter=blob:none "${url}" "$root/${name}" || true
      fi
    '')
    repos);

  pkg = name: lib.attrByPath [name] null pkgs;
  present = names: builtins.filter (package: package != null) (map pkg names);

  baseTools = present [
    # crypto, signing, and secrets hygiene
    "age"
    "rage"
    "sops"
    "gnupg"
    "minisign"
    "cosign"
    "gitleaks"
    "trufflehog"
    "git-secrets"

    # local code / dependency / supply-chain scanning
    "osv-scanner"
    "vulnix"
    "shellcheck"
    "shfmt"
    "hadolint"

    # local network visibility and transport checks
    "nmap"
    "tcpdump"
    "termshark"
    "whois"
    "dnsutils"
    "sslscan"

    # glue for the reference-repo workflow
    "git"
    "ripgrep"
    "fzf"
    "jq"
    "curl"
    "file"
  ];

  deepTools = present [
    # heavier scanners and DFIR helpers; opt in with whycare.security.deep.enable
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
    "chkrootkit"
    "rkhunter"
    "rustscan"
    "testssl"
    "wireshark-cli"
  ];

  securityRepos = pkgs.writeShellScriptBin "security-repos" ''
    set -euo pipefail
    root="${repoRoot}"
    mode="''${1:-sync}"

    case "$mode" in
      list)
        if [ -d "$root" ]; then
          ${pkgs.findutils}/bin/find "$root" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | ${pkgs.coreutils}/bin/sort
        else
          echo "No security reference repos yet. Run: security-repos"
        fi
        exit 0
        ;;
      path)
        echo "$root"
        exit 0
        ;;
      sync|update|pull)
        ;;
      *)
        echo "Usage: security-repos [sync|list|path]" >&2
        exit 2
        ;;
    esac

    ${pkgs.coreutils}/bin/mkdir -p "$root"
    ${repoSyncBody}

    echo
    echo "Security reference repos live in: $root"
    echo "Browse: secsrc security | secsrc hacking | secgrep <term> | sec-menu"
  '';

  securitySources = pkgs.writeShellScriptBin "secsrc" ''
    set -euo pipefail
    root="${repoRoot}"

    case "''${1:-security}" in
      security) repo="awesome-security" ;;
      hacking) repo="awesome-hacking" ;;
      osint) repo="awesome-osint" ;;
      pentest) repo="awesome-pentest" ;;
      web) repo="awesome-web-security" ;;
      ir|incident) repo="awesome-incident-response" ;;
      threat|cti) repo="awesome-threat-intelligence" ;;
      hardening) repo="awesome-security-hardening" ;;
      devsecops) repo="awesome-devsecops" ;;
      yara) repo="awesome-yara" ;;
      *)
        echo "Usage: secsrc {security|hacking|osint|pentest|web|ir|threat|hardening|devsecops|yara}" >&2
        exit 2
        ;;
    esac

    readme="$root/$repo/README.md"
    [ -f "$readme" ] || {
      echo "Reference repo missing: $repo"
      echo "Run: security-repos"
      exit 1
    }

    exec ''${PAGER:-less} "$readme"
  '';

  securitySearch = pkgs.writeShellScriptBin "secgrep" ''
    set -euo pipefail
    root="${repoRoot}"
    [ "$#" -gt 0 ] || {
      echo "Usage: secgrep <search terms>" >&2
      exit 2
    }
    [ -d "$root" ] || {
      echo "Run first: security-repos" >&2
      exit 1
    }

    exec ${pkgs.ripgrep}/bin/rg -n --smart-case "$*" "$root" \
      --glob 'README.md' \
      --glob '*.md'
  '';

  securityMenu = pkgs.writeShellScriptBin "sec-menu" ''
    set -euo pipefail
    root="${repoRoot}"
    [ -d "$root" ] || {
      echo "Run first: security-repos" >&2
      exit 1
    }

    choice="$(${pkgs.findutils}/bin/find "$root" -maxdepth 3 -type f \( -name 'README.md' -o -name '*.md' \) \
      | ${pkgs.gnused}/bin/sed "s#$root/##" \
      | ${pkgs.fzf}/bin/fzf --prompt='security refs> ')"

    [ -n "''${choice:-}" ] || exit 0
    exec ''${PAGER:-less} "$root/$choice"
  '';

  secretScan = pkgs.writeShellScriptBin "secret-scan" ''
    set -u
    target="''${1:-$PWD}"
    status=0

    echo "[*] secret scan target: $target"

    if command -v gitleaks >/dev/null 2>&1; then
      echo "[*] gitleaks"
      gitleaks detect --source "$target" --redact --no-banner || status=$?
    else
      echo "[skip] gitleaks not installed"
    fi

    if command -v trufflehog >/dev/null 2>&1; then
      echo "[*] trufflehog verified filesystem scan"
      trufflehog filesystem "$target" --no-update --results=verified || trufflehog filesystem "$target" --no-update --only-verified || true
    else
      echo "[skip] trufflehog not installed"
    fi

    if command -v git-secrets >/dev/null 2>&1 && [ -d "$target/.git" ]; then
      echo "[*] git-secrets"
      (cd "$target" && git secrets --scan -r) || status=$?
    fi

    exit "$status"
  '';

  supplyChainAudit = pkgs.writeShellScriptBin "supply-chain-audit" ''
    set -u
    target="''${1:-$PWD}"
    status=0

    echo "[*] supply-chain audit target: $target"

    if command -v osv-scanner >/dev/null 2>&1; then
      echo "[*] osv-scanner"
      osv-scanner scan source -r "$target" || osv-scanner -r "$target" || status=$?
    else
      echo "[skip] osv-scanner not installed"
    fi

    if command -v trivy >/dev/null 2>&1; then
      echo "[*] trivy filesystem scan"
      trivy fs --scanners vuln,secret,misconfig "$target" || status=$?
    else
      echo "[skip] trivy not installed; enable whycare.security.deep.enable for heavy tools"
    fi

    if command -v grype >/dev/null 2>&1; then
      echo "[*] grype directory scan"
      grype "dir:$target" || status=$?
    fi

    if command -v syft >/dev/null 2>&1; then
      echo "[*] syft SBOM summary"
      syft "$target" -o table || true
    fi

    if command -v vulnix >/dev/null 2>&1 && [ -f "$target/flake.lock" ]; then
      echo "[*] vulnix flake check"
      (cd "$target" && vulnix --flake .) || true
    fi

    exit "$status"
  '';

  codeAudit = pkgs.writeShellScriptBin "code-audit" ''
    set -u
    target="''${1:-$PWD}"
    status=0

    echo "[*] code audit target: $target"

    if command -v semgrep >/dev/null 2>&1; then
      semgrep scan --config auto "$target" || status=$?
    else
      echo "[skip] semgrep not installed; enable whycare.security.deep.enable"
    fi

    if command -v shellcheck >/dev/null 2>&1; then
      ${pkgs.findutils}/bin/find "$target" -type f -name '*.sh' -print0 \
        | ${pkgs.findutils}/bin/xargs -0 --no-run-if-empty shellcheck || status=$?
    fi

    if command -v hadolint >/dev/null 2>&1; then
      ${pkgs.findutils}/bin/find "$target" -type f \( -name 'Dockerfile' -o -name '*.Dockerfile' \) -print0 \
        | ${pkgs.findutils}/bin/xargs -0 --no-run-if-empty hadolint || status=$?
    fi

    exit "$status"
  '';

  netBaseline = pkgs.writeShellScriptBin "net-baseline" ''
    set -euo pipefail

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  local network baseline"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    echo "[*] addresses"
    ${pkgs.iproute2}/bin/ip -brief address || true
    echo

    echo "[*] routes"
    ${pkgs.iproute2}/bin/ip route || true
    echo

    echo "[*] listening sockets"
    ${pkgs.iproute2}/bin/ss -tulpn || true
    echo

    echo "[*] DNS resolver"
    if command -v resolvectl >/dev/null 2>&1; then
      resolvectl status || true
    else
      cat /etc/resolv.conf || true
    fi
    echo

    echo "[*] public IP through normal route"
    ${pkgs.curl}/bin/curl -fsS https://ifconfig.co/json || true
    echo

    echo "[*] Tor check, if Tor is running locally"
    ${pkgs.curl}/bin/curl -fsS --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip || true
    echo
  '';

  securityCheck = pkgs.writeShellScriptBin "security-check" ''
    set -u
    target="''${1:-$PWD}"
    status=0

    echo "[*] WHOcares security check: $target"
    secret-scan "$target" || status=$?
    supply-chain-audit "$target" || status=$?
    code-audit "$target" || status=$?

    if [ -f "$target/flake.nix" ]; then
      echo "[*] nix flake check --no-build"
      (cd "$target" && nix flake check --no-build --show-trace) || status=$?
    fi

    exit "$status"
  '';

  securityList = pkgs.writeShellScriptBin "security-list" ''
    cat <<'SECURITY_SUITE'
    WHOcares! defensive security suite
    ═════════════════════════════════════

    Reference intelligence, synced manually
      security-repos      clone/update curated GitHub awesome/security repos
      security-repos list list synced repos
      secsrc security     read sbilly/awesome-security
      secsrc hacking      read Hack-with-Github/Awesome-Hacking
      secsrc osint        read jivoi/awesome-osint
      secsrc ir           read incident response resources
      secsrc hardening    read hardening guidance
      secgrep <term>      search all synced reference markdown
      sec-menu            fuzzy browse synced reference markdown

    Local defensive checks
      security-check [dir]       run secret, supply-chain, code, and flake checks
      secret-scan [dir]          gitleaks + trufflehog + git-secrets
      supply-chain-audit [dir]   osv-scanner + optional trivy/grype/syft/vulnix
      code-audit [dir]           semgrep + shellcheck + hadolint
      net-baseline               local addresses, routes, listeners, DNS, egress IP

    Package groups
      base: age/rage/sops/gnupg/minisign/cosign, gitleaks, trufflehog,
            git-secrets, osv-scanner, vulnix, shellcheck, shfmt, hadolint,
            nmap, tcpdump, termshark, whois, dnsutils, sslscan
      deep: semgrep, trivy, grype, syft, yara, clamav, binwalk, sleuthkit,
            hashdeep, lynis, chkrootkit, rkhunter, rustscan, testssl

    Notes
      The GitHub repos are reference material, not executable activation code.
      Run scans only on systems, repos, networks, and accounts you own or are
      explicitly authorized to assess.
    SECURITY_SUITE
  '';
in {
  options.whycare.security = {
    enable = mkEnableOption "WHOcares defensive security suite";

    externalRepos.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Expose manual sync/browse commands for curated security reference repositories.";
    };

    deep.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install heavier DFIR, vulnerability, and code scanning tools.";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      [
        securityList
        secretScan
        supplyChainAudit
        codeAudit
        netBaseline
        securityCheck
      ]
      ++ optionals cfg.externalRepos.enable [
        securityRepos
        securitySources
        securitySearch
        securityMenu
      ]
      ++ baseTools
      ++ optionals cfg.deep.enable deepTools;

    home.sessionVariables = mkIf cfg.externalRepos.enable {
      WHOCARES_SECURITY_REPOS = repoRoot;
      AWESOME_SECURITY = "${repoRoot}/awesome-security";
      AWESOME_HACKING = "${repoRoot}/awesome-hacking";
      AWESOME_OSINT = "${repoRoot}/awesome-osint";
      AWESOME_INCIDENT_RESPONSE = "${repoRoot}/awesome-incident-response";
      AWESOME_SECURITY_HARDENING = "${repoRoot}/awesome-security-hardening";
    };

    programs.zsh.shellAliases =
      {
        sec = "security-list";
        seccheck = "security-check";
        secrets = "secret-scan";
        sca = "supply-chain-audit";
        caudit = "code-audit";
        netbase = "net-baseline";
      }
      // optionalAttrs cfg.externalRepos.enable {
        secrepos = "security-repos";
        secrepo-list = "security-repos list";
        secpath = "security-repos path";
        ssrc = "secsrc";
      };

    programs.nushell.extraConfig = ''
      alias sec = security-list
      alias seccheck = security-check
      alias secrets = secret-scan
      alias sca = supply-chain-audit
      alias caudit = code-audit
      alias netbase = net-baseline
      alias secrepos = security-repos
      alias ssrc = secsrc
    '';

    xdg.dataFile."whocares/security-suite.md".text = ''
      # WHOcares! defensive security suite

      This module maps practical defensive tooling from curated security awesome-lists
      into pinned nixpkgs packages, then keeps the GitHub repositories as optional
      local reference material.

      ## Reference repositories

      ${lib.concatMapStringsSep "\n" (name: "- `${name}` → `${repos.${name}}`") repoNames}

      ## Commands

      - `security-list` / `sec`: overview
      - `security-repos`: clone or update reference repositories on demand
      - `secsrc <topic>`: read a synced list
      - `secgrep <term>`: search synced markdown
      - `security-check [dir]`: run local defensive checks
      - `secret-scan [dir]`: scan for leaked secrets
      - `supply-chain-audit [dir]`: dependency and SBOM checks
      - `code-audit [dir]`: static analysis checks
      - `net-baseline`: inspect local network state

      ## Safety boundary

      This is wired for owned-machine defense, reproducible workstation auditing,
      and authorized lab work. It deliberately treats cloned GitHub lists as reading
      material instead of executable activation dependencies.
    '';
  };
}
