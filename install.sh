#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Prepare a WHOcares! checkout for this machine. The script copies the framework
to the target directory, writes machine-local settings.nix, and runs a no-build
flake check when Nix is available.

Options:
  --target PATH        Install/copy destination (default: $HOME/WHOcares)
  --user NAME          Home Manager/NixOS user name (default: current user)
  --home PATH          Home directory for that user (default: $HOME)
  --email ADDRESS      Git/email identity in settings.nix
  --home-host HOST     Default Home Manager host: workstation, laptop, hp-laptop, coffin, Aegis-Dualis
  --nixos-host HOST    Default NixOS host: workstation, laptop, hp-laptop, Aegis-Dualis
  --skip-check         Do not run nix flake check after writing settings.nix
  --in-place           Configure the current checkout instead of copying it
  -h, --help           Show this help

Examples:
  ./install.sh --home-host workstation
  ./install.sh --target "$HOME/WHOcares" --user "$USER" --home-host laptop
  ./install.sh --in-place --home-host coffin --nixos-host Aegis-Dualis
EOF
}

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 2
}

short_hostname() {
  hostname -s 2>/dev/null || hostname 2>/dev/null || printf 'localhost'
}

nix_escape() {
  local value=${1//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

known_home_host() {
  case "$1" in
    coffin | workstation | laptop | hp-laptop | Aegis-Dualis) return 0 ;;
    *) return 1 ;;
  esac
}

known_nixos_host() {
  case "$1" in
    workstation | laptop | hp-laptop | Aegis-Dualis) return 0 ;;
    *) return 1 ;;
  esac
}

copy_tree() {
  local source_path=$1
  local target_path=$2

  mkdir -p "$target_path"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude=.git \
      --exclude=.direnv \
      --exclude=result \
      --exclude='result-*' \
      "$source_path/" "$target_path/"
  else
    (
      cd "$source_path"
      tar \
        --exclude=.git \
        --exclude=.direnv \
        --exclude=result \
        --exclude='result-*' \
        -cf - .
    ) | (
      cd "$target_path"
      tar -xf -
    )
  fi
}

write_settings() {
  local target_path=$1
  local user_name=$2
  local user_email=$3
  local user_home=$4
  local home_host=$5
  local nixos_host=$6

  local target_nix user_nix email_nix home_nix home_host_nix nixos_host_nix
  target_nix=$(nix_escape "$target_path")
  user_nix=$(nix_escape "$user_name")
  email_nix=$(nix_escape "$user_email")
  home_nix=$(nix_escape "$user_home")
  home_host_nix=$(nix_escape "$home_host")
  nixos_host_nix=$(nix_escape "$nixos_host")

  cat >"$target_path/settings.nix" <<EOF
{
  repositoryPath = "$target_nix";

  defaultSystem = "x86_64-linux";
  supportedSystems = ["x86_64-linux"];

  user = {
    name = "$user_nix";
    email = "$email_nix";
    homeDirectory = "$home_nix";
  };

  defaultHomeHost = "$home_host_nix";
  defaultNixosHost = "$nixos_host_nix";

  homeProfiles = {
    coffin = {
      system = "x86_64-linux";
      genericLinux = true;
    };

    workstation = {
      system = "x86_64-linux";
      genericLinux = true;
    };

    laptop = {
      system = "x86_64-linux";
      genericLinux = true;
    };

    hp-laptop = {
      system = "x86_64-linux";
      genericLinux = true;
    };

    "Aegis-Dualis" = {
      system = "x86_64-linux";
      genericLinux = false;
    };
  };

  nixosHosts = {
    "Aegis-Dualis" = {
      system = "x86_64-linux";
      modules = [./hosts/aegis-dualis];
    };

    workstation = {
      system = "x86_64-linux";
      modules = [./hosts/workstation];
    };

    laptop = {
      system = "x86_64-linux";
      modules = [./hosts/laptop];
    };

    hp-laptop = {
      system = "x86_64-linux";
      modules = [./hosts/hp-laptop];
    };
  };
}
EOF
}

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
target="${WHOCARES_TARGET:-$HOME/WHOcares}"
user_name="${WHOCARES_USER:-$(id -un)}"
user_home="${WHOCARES_HOME:-$HOME}"
user_email="${WHOCARES_EMAIL:-$user_name@$(short_hostname)}"
home_host="${WHOCARES_HOST:-workstation}"
nixos_host="${WHOCARES_NIXOS_HOST:-workstation}"
run_check=1
in_place=0

while (($#)); do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || die "--target requires a path"
      target=$2
      shift 2
      ;;
    --user)
      [[ $# -ge 2 ]] || die "--user requires a name"
      user_name=$2
      shift 2
      ;;
    --home)
      [[ $# -ge 2 ]] || die "--home requires a path"
      user_home=$2
      shift 2
      ;;
    --email)
      [[ $# -ge 2 ]] || die "--email requires an address"
      user_email=$2
      shift 2
      ;;
    --home-host)
      [[ $# -ge 2 ]] || die "--home-host requires a host"
      home_host=$2
      shift 2
      ;;
    --nixos-host)
      [[ $# -ge 2 ]] || die "--nixos-host requires a host"
      nixos_host=$2
      shift 2
      ;;
    --skip-check)
      run_check=0
      shift
      ;;
    --in-place)
      in_place=1
      target=$source_dir
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

known_home_host "$home_host" || die "unknown Home Manager host: $home_host"
known_nixos_host "$nixos_host" || die "unknown NixOS host: $nixos_host"

source_path="$(realpath -m -- "$source_dir")"
target_path="$(realpath -m -- "$target")"
user_home_path="$(realpath -m -- "$user_home")"

if ((in_place)); then
  printf '[*] configuring WHOcares! in place at %s\n' "$target_path"
elif [[ "$source_path" == "$target_path" ]]; then
  printf '[*] WHOcares! is already at %s\n' "$target_path"
else
  copy_tree "$source_path" "$target_path"
  printf '[*] copied WHOcares! to %s\n' "$target_path"
fi

write_settings "$target_path" "$user_name" "$user_email" "$user_home_path" "$home_host" "$nixos_host"
printf '[*] wrote %s/settings.nix for %s@%s\n' "$target_path" "$user_name" "$home_host"

if ((run_check)); then
  if command -v nix >/dev/null 2>&1; then
    printf '[*] running no-build flake check\n'
    nix flake check --no-build --show-trace "path:$target_path"
  else
    printf '[!] nix is not on PATH; skipping flake check\n' >&2
  fi
fi

cat <<EOF

[*] next:
  cd "$target_path"
  nix run path:$target_path#info
  nix run path:$target_path#home-build
  nix run path:$target_path#home-switch

For NixOS deployment, add hosts/<host>/hardware-configuration.nix and an
explicit hosts/<host>/disko.nix first, then use:
  nix run path:$target_path#nixos-install -- $nixos_host root@<target-ip>

For an existing NixOS machine, use:
  WHOCARES_NIXOS_HOST=$nixos_host nix run path:$target_path#nixos-switch
EOF
