#!/usr/bin/env bash
set -euo pipefail

default_flake="__WHOCARES_DEFAULT_FLAKE__"
default_user="__WHOCARES_DEFAULT_USER__"
default_home_host="__WHOCARES_DEFAULT_HOME_HOST__"
default_nixos_host="__WHOCARES_DEFAULT_NIXOS_HOST__"
default_system="__WHOCARES_DEFAULT_SYSTEM__"

if script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"; then
  :
else
  script_dir="$(pwd -P)"
fi

if script_root="$(cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"; then
  :
else
  script_root="$(pwd -P)"
fi

if [[ "$default_flake" == "__WHOCARES_DEFAULT_FLAKE__" ]]; then
  default_flake="$script_root"
fi
if [[ "$default_user" == "__WHOCARES_DEFAULT_USER__" ]]; then
  default_user="$(id -un 2>/dev/null || printf 'user')"
fi
if [[ "$default_home_host" == "__WHOCARES_DEFAULT_HOME_HOST__" ]]; then
  default_home_host="$(hostname -s 2>/dev/null || printf 'host')"
fi
if [[ "$default_nixos_host" == "__WHOCARES_DEFAULT_NIXOS_HOST__" ]]; then
  default_nixos_host="$default_home_host"
fi
if [[ "$default_system" == "__WHOCARES_DEFAULT_SYSTEM__" ]]; then
  default_system="${NIX_SYSTEM:-x86_64-linux}"
fi

workflow="${1:-plan}"
case "$workflow" in
  -h | --help)
    workflow="help"
    ;;
  *)
    if [[ $# -gt 0 ]]; then
      shift
    fi
    ;;
esac
plan_workflow="$workflow"

flake="${WHOCARES_FLAKE:-${AEGIS_FLAKE:-$default_flake}}"
home_host="${WHOCARES_HOST:-${AEGIS_HOST:-$default_home_host}}"
nixos_host="${WHOCARES_NIXOS_HOST:-${AEGIS_NIXOS_HOST:-$default_nixos_host}}"
profile="${WHOCARES_PROFILE:-${AEGIS_PROFILE:-$default_user@$home_host}}"
system="${WHOCARES_SYSTEM:-$default_system}"
ssh_target="${WHOCARES_SSH_TARGET:-}"
jobs="${WHOCARES_NIX_JOBS:-1}"
cores="${WHOCARES_NIX_CORES:-2}"
nice_value="${WHOCARES_NICE:-10}"
yes=0
dry_run=0
skip_source_quality=0
skip_eval=0
extra_args=()

usage() {
  cat <<EOF
Usage: whocares-pipeline <workflow> [options] [-- extra args]

Workflows:
  inputs           Print the input worksheet for every pipeline.
  plan [workflow]  Show resolved inputs and the stage order for a workflow.
  validate         Evaluate flake outputs and run the source-quality check.
  bootstrap-check  Copy to a temp checkout, generate settings.nix, and run #info.
  home-build       Validate, then build the selected Home Manager profile.
  home-switch      Validate, build, then activate Home Manager. Requires confirmation or --yes.
  nixos-build      Validate, then build the selected NixOS host toplevel.
  nixos-switch     Validate, build, then run nixos-rebuild switch. Requires confirmation or --yes.
  nixos-install    Guarded nixos-anywhere install. Requires --target and confirmation or --yes.

Options:
  --flake PATH|REF       Checkout path or flake ref. Default: $flake
  --host HOST            Home Manager host suffix. Default: $home_host
  --profile PROFILE      Full Home Manager profile. Default: $profile
  --nixos-host HOST      NixOS host output. Default: $nixos_host
  --system SYSTEM        Check system. Default: $system
  --target SSH_TARGET    SSH target for nixos-install.
  --skip-source-quality  Do not build checks.<system>.source-quality.
  --skip-eval            Skip no-build flake evaluation.
  --dry-run              Print commands without executing them.
  -y, --yes              Allow activation or install stages without prompting.
  -h, --help             Show this help.

Environment inputs:
  WHOCARES_FLAKE, WHOCARES_HOST, WHOCARES_PROFILE, WHOCARES_NIXOS_HOST
  WHOCARES_SYSTEM, WHOCARES_SSH_TARGET, WHOCARES_NIX_JOBS, WHOCARES_NIX_CORES
  WHOCARES_NICE, WHOCARES_INSTALL_WITHOUT_DISKO
EOF
}

while (($#)); do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      ;;
    *)
      if [[ "$workflow" == "plan" && "$plan_workflow" == "plan" ]]; then
        plan_workflow="$1"
        shift
        continue
      fi
      ;;
  esac

  case "$1" in
    --flake)
      [[ $# -ge 2 ]] || {
        echo "--flake requires a value" >&2
        exit 2
      }
      flake="$2"
      shift 2
      ;;
    --host)
      [[ $# -ge 2 ]] || {
        echo "--host requires a value" >&2
        exit 2
      }
      home_host="$2"
      profile="${WHOCARES_PROFILE:-${AEGIS_PROFILE:-$default_user@$home_host}}"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || {
        echo "--profile requires a value" >&2
        exit 2
      }
      profile="$2"
      shift 2
      ;;
    --nixos-host)
      [[ $# -ge 2 ]] || {
        echo "--nixos-host requires a value" >&2
        exit 2
      }
      nixos_host="$2"
      shift 2
      ;;
    --system)
      [[ $# -ge 2 ]] || {
        echo "--system requires a value" >&2
        exit 2
      }
      system="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || {
        echo "--target requires a value" >&2
        exit 2
      }
      ssh_target="$2"
      shift 2
      ;;
    --skip-source-quality)
      skip_source_quality=1
      shift
      ;;
    --skip-eval)
      skip_eval=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -y | --yes)
      yes=1
      shift
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

local_root=""
case "$flake" in
  *:*)
    flake_ref="$flake"
    ;;
  *)
    local_root="$(realpath -m -- "$flake")"
    flake_ref="path:$local_root"
    ;;
esac

require_local_root() {
  if [[ -z "$local_root" ]]; then
    echo "workflow '$workflow' requires a local checkout path, not flake ref '$flake_ref'" >&2
    exit 2
  fi
  if [[ ! -f "$local_root/flake.nix" ]]; then
    echo "no flake.nix found at $local_root" >&2
    exit 2
  fi
}

print_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}

run_cmd() {
  print_cmd "$@"
  if ((dry_run)); then
    return 0
  fi
  "$@"
}

confirm() {
  local action=$1
  if ((yes)); then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "$action requires --yes when stdin is not interactive" >&2
    exit 4
  fi
  local reply
  read -r -p "$action [y/N] " reply
  case "$reply" in
    y | Y | yes | YES) ;;
    *)
      echo "aborted"
      exit 4
      ;;
  esac
}

print_inputs() {
  cat <<EOF
WHOcares pipeline inputs

Identity:
  user/profile:     $profile
  home host:        $home_host
  NixOS host:       $nixos_host

Repository:
  flake input:      $flake
  flake ref:        $flake_ref
  local root:       ${local_root:-not a local path}
  system:           $system

Resource policy:
  jobs:             $jobs
  cores:            $cores
  nice:             $nice_value

Install target:
  ssh target:       ${ssh_target:-not set}
  disko override:   ${WHOCARES_INSTALL_WITHOUT_DISKO:-0}

Required per workflow:
  validate:         flake.nix, flake.lock, checks.$system.source-quality
  bootstrap-check:  local checkout with ./install.sh
  home-build:       Home Manager profile $profile
  home-switch:      home-build inputs plus --yes or interactive confirmation
  nixos-build:      nixosConfigurations.$nixos_host
  nixos-switch:     nixos-build inputs plus sudo and confirmation
  nixos-install:    hosts/$nixos_host/disko.nix, SSH target, confirmation
EOF
}

print_plan() {
  print_inputs
  cat <<EOF

Stage order for '$plan_workflow':
EOF
  case "$plan_workflow" in
    inputs) echo "  1. print input worksheet" ;;
    plan) echo "  1. print this plan" ;;
    validate)
      echo "  1. no-build flake evaluation"
      echo "  2. source-quality derivation"
      ;;
    bootstrap-check)
      echo "  1. copy checkout to a temporary directory"
      echo "  2. run install.sh --skip-check"
      echo "  3. run #info from the copied checkout"
      ;;
    home-build)
      echo "  1. validate"
      echo "  2. home-manager build"
      ;;
    home-switch)
      echo "  1. validate"
      echo "  2. home-manager build"
      echo "  3. confirmation"
      echo "  4. home-manager switch"
      ;;
    nixos-build)
      echo "  1. validate"
      echo "  2. nix build selected NixOS toplevel"
      ;;
    nixos-switch)
      echo "  1. validate"
      echo "  2. nix build selected NixOS toplevel"
      echo "  3. confirmation"
      echo "  4. sudo nixos-rebuild switch"
      ;;
    nixos-install)
      echo "  1. validate local checkout"
      echo "  2. check hosts/$nixos_host/disko.nix guard"
      echo "  3. confirmation"
      echo "  4. nixos-anywhere"
      ;;
    *)
      echo "unknown workflow: $workflow" >&2
      exit 2
      ;;
  esac
}

validate() {
  if ((!skip_eval)); then
    run_cmd nix flake check --no-build --show-trace "$flake_ref"
  fi
  if ((!skip_source_quality)); then
    run_cmd nix build "$flake_ref#checks.$system.source-quality" --no-link
  fi
}

home_build() {
  validate
  run_cmd nice -n "$nice_value" ionice -c2 -n7 home-manager build \
    --flake "$flake_ref#$profile" \
    --option max-jobs "$jobs" \
    --option cores "$cores" \
    "${extra_args[@]}"
}

home_switch() {
  validate
  run_cmd nice -n "$nice_value" ionice -c2 -n7 home-manager build \
    --flake "$flake_ref#$profile" \
    --option max-jobs "$jobs" \
    --option cores "$cores"
  confirm "Activate Home Manager profile $profile from $flake_ref?"
  run_cmd nice -n "$nice_value" ionice -c2 -n7 home-manager switch \
    --flake "$flake_ref#$profile" \
    --option max-jobs "$jobs" \
    --option cores "$cores" \
    "${extra_args[@]}"
}

nixos_build() {
  validate
  run_cmd nice -n "$nice_value" ionice -c2 -n7 nix build \
    "$flake_ref#nixosConfigurations.$nixos_host.config.system.build.toplevel" \
    --max-jobs "$jobs" \
    --cores "$cores" \
    "${extra_args[@]}"
}

nixos_switch() {
  nixos_build
  confirm "Switch NixOS host $nixos_host from $flake_ref?"
  run_cmd sudo nixos-rebuild switch \
    --flake "$flake_ref#$nixos_host" \
    --max-jobs "$jobs" \
    --cores "$cores" \
    "${extra_args[@]}"
}

nixos_install() {
  require_local_root
  [[ -n "$ssh_target" ]] || {
    echo "nixos-install requires --target root@host or WHOCARES_SSH_TARGET" >&2
    exit 2
  }
  host_dir="$local_root/hosts/$nixos_host"
  [[ -d "$host_dir" ]] || {
    echo "unknown host '$nixos_host' at $host_dir" >&2
    exit 2
  }
  if [[ ! -f "$host_dir/disko.nix" && "${WHOCARES_INSTALL_WITHOUT_DISKO:-0}" != "1" ]]; then
    echo "refusing install without $host_dir/disko.nix" >&2
    echo "set WHOCARES_INSTALL_WITHOUT_DISKO=1 only for a deliberate custom phase" >&2
    exit 3
  fi
  confirm "Run nixos-anywhere for $nixos_host on $ssh_target?"
  run_cmd nice -n "$nice_value" ionice -c2 -n7 nixos-anywhere \
    --flake "$flake_ref#$nixos_host" \
    --option max-jobs "$jobs" \
    --option cores "$cores" \
    "${extra_args[@]}" \
    "$ssh_target"
}

bootstrap_check() {
  require_local_root
  tmpdir="$(mktemp -d)"
  run_cmd "$local_root/install.sh" --target "$tmpdir/WHOcares" --home-host "$home_host" --nixos-host "$nixos_host" --skip-check
  run_cmd env -u AEGIS_FLAKE -u WHOCARES_FLAKE nix run "path:$tmpdir/WHOcares#info"
}

case "$workflow" in
  help) usage ;;
  inputs) print_inputs ;;
  plan) print_plan ;;
  validate) validate ;;
  bootstrap-check) bootstrap_check ;;
  home-build) home_build ;;
  home-switch) home_switch ;;
  nixos-build) nixos_build ;;
  nixos-switch) nixos_switch ;;
  nixos-install) nixos_install ;;
  *)
    echo "unknown workflow: $workflow" >&2
    usage >&2
    exit 2
    ;;
esac
