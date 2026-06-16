# ---------------------------------------------------------------------------
# llm-orchestrator.nix — WHOcares! non-coder automation + LLM context bridge
#
# Purpose:
#   • turn day-to-day commands into discoverable "skills"
#   • capture repo/system/build context for ChatGPT/Gemini/other cloud LLMs
#   • create fixpacks from failing Nix/Home Manager runs
#   • apply AI-generated patches safely on a throwaway git branch
#   • keep all cloud handoff explicit: copy to clipboard, then open browser
# ---------------------------------------------------------------------------
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.whycare.llmOrchestrator;

  dataDir = "${config.xdg.dataHome}/whocares/llm-orchestrator";
  stateDir = "${config.xdg.stateHome}/whocares/llm-orchestrator";
  registryPath = "${dataDir}/commands.tsv";

  browser = escapeShellArg cfg.browser;
  maxFileBytes = toString cfg.maxFileBytes;
  maxFilesBrief = toString cfg.maxFilesBrief;
  maxFilesFull = toString cfg.maxFilesFull;

  commonShell = ''
    copy_file() {
      file="$1"
      if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$file"
        echo "[copied] $file -> Wayland clipboard"
      elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard < "$file"
        echo "[copied] $file -> X11 clipboard"
      else
        echo "[warn] No clipboard tool found. Install wl-clipboard or xclip." >&2
        return 1
      fi
    }

    open_provider() {
      provider="''${1:-chatgpt}"
      case "$provider" in
        chatgpt|gpt|openai) url="https://chatgpt.com/" ;;
        gemini|google) url="https://gemini.google.com/app" ;;
        claude|anthropic) url="https://claude.ai/new" ;;
        perplexity|px) url="https://www.perplexity.ai/" ;;
        copilot|bing) url="https://copilot.microsoft.com/" ;;
        *)
          echo "Unknown provider: $provider" >&2
          echo "Providers: chatgpt, gemini, claude, perplexity, copilot" >&2
          return 2
          ;;
      esac

      if command -v ${browser} >/dev/null 2>&1; then
        ${pkgs.coreutils}/bin/nohup ${browser} "$url" >/dev/null 2>&1 &
      elif command -v xdg-open >/dev/null 2>&1; then
        ${pkgs.coreutils}/bin/nohup ${pkgs.xdg-utils}/bin/xdg-open "$url" >/dev/null 2>&1 &
      else
        echo "Open this URL manually: $url" >&2
        return 1
      fi
      echo "[opened] $provider"
    }

    redact_stream() {
      ${pkgs.gnused}/bin/sed -E \
        -e 's/([A-Za-z0-9_.-]*(TOKEN|SECRET|PASSWORD|PASS|API[_-]?KEY|PRIVATE[_-]?KEY)[A-Za-z0-9_.-]*[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"']+/\1<redacted>/Ig' \
        -e 's/(Authorization:[[:space:]]*)(Bearer|Basic)[[:space:]][^[:space:]]+/\1<redacted>/Ig' \
        -e 's/(sk-[A-Za-z0-9_-]{16,})/<redacted-openai-like-key>/g' \
        -e 's/(gh[pousr]_[A-Za-z0-9_]{20,})/<redacted-github-like-token>/g'
    }
  '';

  commandRegistry = ''
    command	category	purpose	example
    why	discovery	Show what WHOcares commands do, by name or search term	why ctx
    skills	discovery	Alias for the command registry	skills llm
    ctx	llm-context	Capture repo, Nix, git, shell, and safe system context as Markdown	ctx --copy --open chatgpt
    ctxc	llm-context	Copy current context bundle to clipboard	ctxc
    ctxf	llm-context	Save current context bundle under ~/.local/state	ctxf
    llm-copy	llm-context	Copy stdin, files, or directory context into the clipboard for any LLM	git diff | llm-copy
    llm-open	llm-context	Copy a prompt/context bundle, then open ChatGPT/Gemini/Claude/etc.	llm-open gemini README.md
    llm-chatgpt	llm-context	Copy prompt/context and open ChatGPT	ctx | llm-chatgpt
    llm-gemini	llm-context	Copy prompt/context and open Gemini	ctx | llm-gemini
    runlog	automation	Run any command, save transcript, create an LLM-ready failure prompt	runlog hm-check
    hm-doctor	nix-repair	Build a Home Manager/Nix diagnostic bundle and copy it for LLM review	hm-doctor
    nix-fixpack	nix-repair	Run flake/HM checks, save logs, create one pasteable debug pack	nix-fixpack --open chatgpt
    llm-review	git-review	Package git status/diff/context for an LLM code review	llm-review --open gemini
    llm-patch	git-automation	Safely apply an AI patch on a new branch and run checks	llm-patch fix.patch
    aipatch	git-automation	Alias for llm-patch	aipatch --clipboard
    lastlog	zsh-automation	Zsh function: rerun previous command through runlog	lastlog
    lastask	zsh-automation	Zsh function: ask an LLM to explain the previous command	lastask
  '';

  ctx = pkgs.writeShellScriptBin "ctx" ''
    set -uo pipefail
    ${commonShell}

    target="$PWD"
    mode="brief"
    do_copy=0
    do_save=0
    out=""
    provider=""

    usage() {
      cat <<'USAGE'
    Usage: ctx [--brief|--full] [--target DIR] [--save] [--output FILE] [--copy] [--open PROVIDER]

    Captures an LLM-ready Markdown bundle:
      • repo path, git status, recent commits, and diffs
      • flake/Home Manager clues when present
      • relevant project files, bounded and redacted
      • local shell/system/network basics useful for debugging

    Providers for --open: chatgpt, gemini, claude, perplexity, copilot
    USAGE
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --brief) mode="brief" ;;
        --full) mode="full" ;;
        --target|-C)
          shift
          target="''${1:?--target requires a directory}"
          ;;
        --save) do_save=1 ;;
        --output|-o)
          shift
          out="''${1:?--output requires a path}"
          ;;
        --copy) do_copy=1 ;;
        --open)
          shift
          provider="''${1:?--open requires a provider}"
          do_copy=1
          ;;
        -h|--help) usage; exit 0 ;;
        *)
          if [ -d "$1" ]; then
            target="$1"
          else
            echo "Unknown ctx argument: $1" >&2
            usage >&2
            exit 2
          fi
          ;;
      esac
      shift
    done

    if [ ! -d "$target" ]; then
      echo "ctx target is not a directory: $target" >&2
      exit 2
    fi

    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    tmp_owned=0
    if [ -z "$out" ]; then
      if [ "$do_save" -eq 1 ] || [ "$do_copy" -eq 1 ] || [ -n "$provider" ]; then
        out="''${WHOCARES_LLM_STATE:-${stateDir}}/context/context-$stamp.md"
      else
        out="$(${pkgs.coreutils}/bin/mktemp)"
        tmp_owned=1
      fi
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$out")"

    root="$(${pkgs.bash}/bin/bash -lc 'cd "$1" && git rev-parse --show-toplevel 2>/dev/null || pwd' _ "$target")"
    max_files=${maxFilesBrief}
    depth=4
    if [ "$mode" = "full" ]; then
      max_files=${maxFilesFull}
      depth=7
    fi

    append_cmd() {
      title="$1"
      shift
      {
        echo
        echo "## $title"
        echo '```text'
        (cd "$root" && "$@") 2>&1 | redact_stream || true
        echo '```'
      } >> "$out"
    }

    append_file() {
      abs="$1"
      rel="$2"
      [ -f "$abs" ] || return 0
      bytes="$(${pkgs.coreutils}/bin/wc -c < "$abs" | ${pkgs.gnused}/bin/sed 's/[[:space:]]//g')"
      {
        echo
        echo "## File: $rel"
        echo '```text'
        if [ "$bytes" -le ${maxFileBytes} ]; then
          ${pkgs.coreutils}/bin/cat "$abs" | redact_stream
        else
          echo "[truncated: $bytes bytes; first ${maxFileBytes} bytes shown]"
          ${pkgs.coreutils}/bin/head -c ${maxFileBytes} "$abs" | redact_stream
          echo
        fi
        echo '```'
      } >> "$out"
    }

    {
      echo "# WHOcares! LLM Context Bundle"
      echo
      echo "Generated: $(${pkgs.coreutils}/bin/date -Is)"
      echo "Mode: $mode"
      echo "Target: $target"
      echo "Detected root: $root"
      echo "Host: $(${pkgs.coreutils}/bin/uname -n)"
      echo "User: $USER"
      echo
      echo "## Use this prompt"
      echo "You are helping debug or extend my WHOcares!/Nix/Home Manager workstation. Read the context below, identify the concrete issue or next automation step, and give exact commands or a patch. Prefer safe, reversible changes."
    } > "$out"

    append_cmd "System basics" ${pkgs.bash}/bin/bash -lc 'uname -a; echo; command -v nix >/dev/null && nix --version || true; command -v home-manager >/dev/null && home-manager --version || true; command -v nh >/dev/null && nh --version || true; echo; printf "SHELL=%s\nPATH=%s\n" "$SHELL" "$PATH"'
    append_cmd "Working tree" ${pkgs.bash}/bin/bash -lc 'pwd; echo; git status --short --branch 2>/dev/null || true; echo; git log --oneline --decorate -8 2>/dev/null || true'
    append_cmd "Diff summary" ${pkgs.bash}/bin/bash -lc 'git diff --stat 2>/dev/null || true; echo; git diff --staged --stat 2>/dev/null || true'

    if [ -f "$root/flake.nix" ]; then
      append_cmd "Flake outputs" ${pkgs.bash}/bin/bash -lc 'nix flake show --all-systems --no-write-lock-file . 2>/dev/null || true'
    fi

    append_cmd "Network/device basics" ${pkgs.bash}/bin/bash -lc 'ip -brief address 2>/dev/null || true; echo; ip route 2>/dev/null || true; echo; command -v nmcli >/dev/null && nmcli device status || true'

    {
      echo
      echo "## Selected project files"
      echo "Showing up to $max_files files, max ${maxFileBytes} bytes each. Heavy/generated directories are excluded."
    } >> "$out"

    file_list="$(${pkgs.coreutils}/bin/mktemp)"
    (
      cd "$root" &&
      ${pkgs.fd}/bin/fd -HI -t f -d "$depth" \
        -E .git -E result -E node_modules -E .direnv -E .venv -E target -E dist -E build -E __pycache__ \
        '(flake\.nix|settings\.nix|default\.nix|README\.md|CONTRIBUTING\.md|statix\.toml|.*\.(nix|sh|md|toml|kdl|json|yaml|yml|service|desktop))$' . \
        | ${pkgs.coreutils}/bin/head -n "$max_files"
    ) > "$file_list" 2>/dev/null || true

    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      append_file "$root/$rel" "$rel"
    done < "$file_list"
    ${pkgs.coreutils}/bin/rm -f "$file_list"

    if [ "$do_copy" -eq 1 ]; then
      copy_file "$out" || true
    fi
    if [ -n "$provider" ]; then
      open_provider "$provider" || true
    fi

    if [ "$tmp_owned" -eq 1 ]; then
      ${pkgs.coreutils}/bin/cat "$out"
      ${pkgs.coreutils}/bin/rm -f "$out"
    else
      echo "$out"
    fi
  '';

  llmCopy = pkgs.writeShellScriptBin "llm-copy" ''
    set -uo pipefail
    ${commonShell}

    out="$(${pkgs.coreutils}/bin/mktemp)"

    if [ "$#" -gt 0 ]; then
      {
        echo "# LLM Handoff"
        echo
        echo "Use the following material to help me. Preserve exact commands and paths."
        for item in "$@"; do
          echo
          echo "## Source: $item"
          if [ -d "$item" ]; then
            ctx --target "$item" --brief
          elif [ -f "$item" ]; then
            echo '```text'
            ${pkgs.coreutils}/bin/cat "$item" | redact_stream
            echo '```'
          else
            echo "[missing] $item"
          fi
        done
      } > "$out"
    elif [ -t 0 ]; then
      ctx --brief > "$out"
    else
      {
        echo "# LLM Handoff"
        echo
        echo "Use the following terminal input/context to help me."
        echo
        echo '```text'
        ${pkgs.coreutils}/bin/cat | redact_stream
        echo '```'
      } > "$out"
    fi

    copy_file "$out" || true
    echo "$out"
  '';

  llmOpen = pkgs.writeShellScriptBin "llm-open" ''
    set -uo pipefail
    ${commonShell}

    provider="chatgpt"
    case "''${1:-}" in
      chatgpt|gpt|openai|gemini|google|claude|anthropic|perplexity|px|copilot|bing)
        provider="$1"
        shift
        ;;
    esac

    out="$(${pkgs.coreutils}/bin/mktemp)"
    if [ "$#" -gt 0 ]; then
      {
        echo "# LLM Handoff"
        echo
        echo "I am pasting context/files from my WHOcares workstation. Help me turn it into safe exact next steps."
        for item in "$@"; do
          echo
          echo "## Source: $item"
          if [ -d "$item" ]; then
            ctx --target "$item" --brief
          elif [ -f "$item" ]; then
            echo '```text'
            ${pkgs.coreutils}/bin/cat "$item" | redact_stream
            echo '```'
          else
            echo "[missing] $item"
          fi
        done
      } > "$out"
    elif [ -t 0 ]; then
      ctx --brief > "$out"
    else
      {
        echo "# LLM Handoff"
        echo
        echo "Use this pasted terminal context to help me."
        echo
        echo '```text'
        ${pkgs.coreutils}/bin/cat | redact_stream
        echo '```'
      } > "$out"
    fi

    copy_file "$out" || true
    open_provider "$provider" || true
    echo "$out"
  '';

  llmChatgpt = pkgs.writeShellScriptBin "llm-chatgpt" ''
    exec llm-open chatgpt "$@"
  '';

  llmGemini = pkgs.writeShellScriptBin "llm-gemini" ''
    exec llm-open gemini "$@"
  '';

  runlog = pkgs.writeShellScriptBin "runlog" ''
    set -uo pipefail
    ${commonShell}

    [ "$#" -gt 0 ] || {
      echo "Usage: runlog <command> [args...]" >&2
      exit 2
    }

    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    outdir="''${WHOCARES_LLM_STATE:-${stateDir}}/runlog/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir"
    log="$outdir/command.log"
    prompt="$outdir/ask-llm.md"

    printf '%q ' "$@" > "$outdir/command.txt"
    echo "[runlog] $(${pkgs.coreutils}/bin/cat "$outdir/command.txt")"

    set +e
    "$@" 2>&1 | ${pkgs.coreutils}/bin/tee "$log"
    status="''${PIPESTATUS[0]}"
    set -u

    ctx --brief --output "$outdir/context.md" >/dev/null 2>&1 || true

    {
      echo "# Command Debug Request"
      echo
      echo "The command below exited with status $status. Explain the failure and give exact next commands. Prefer a safe patch if code/config is wrong."
      echo
      echo "## Command"
      echo '```sh'
      ${pkgs.coreutils}/bin/cat "$outdir/command.txt"
      echo
      echo '```'
      echo
      echo "## Log"
      echo '```text'
      ${pkgs.coreutils}/bin/cat "$log" | redact_stream
      echo '```'
      echo
      echo "## Context"
      ${pkgs.coreutils}/bin/cat "$outdir/context.md" 2>/dev/null || true
    } > "$prompt"

    copy_file "$prompt" >/dev/null 2>&1 || true
    echo
    echo "[saved] $outdir"
    echo "[prompt] $prompt"
    exit "$status"
  '';

  nixFixpack = pkgs.writeShellScriptBin "nix-fixpack" ''
    set -uo pipefail
    ${commonShell}

    provider=""
    target="$PWD"

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --open)
          shift
          provider="''${1:?--open requires a provider}"
          ;;
        --target|-C)
          shift
          target="''${1:?--target requires a directory}"
          ;;
        -h|--help)
          cat <<'USAGE'
    Usage: nix-fixpack [--target DIR] [--open chatgpt|gemini|claude|perplexity]

    Creates one diagnostic folder with:
      context.md       repo/system/Nix context
      nix-flake-check.log
      hm-check.log     when hm-check is available
      nix-audit.log    when nix-audit is available
      ask-llm.md       pasteable cloud-LLM prompt, copied to clipboard
    USAGE
          exit 0
          ;;
        *)
          if [ -d "$1" ]; then target="$1"; else echo "Unknown arg: $1" >&2; exit 2; fi
          ;;
      esac
      shift
    done

    root="$(${pkgs.bash}/bin/bash -lc 'cd "$1" && git rev-parse --show-toplevel 2>/dev/null || pwd' _ "$target")"
    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    outdir="''${WHOCARES_LLM_STATE:-${stateDir}}/fixpacks/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir"

    echo "[fixpack] root: $root"
    ctx --target "$root" --full --output "$outdir/context.md" >/dev/null || true

    run_check() {
      name="$1"
      shift
      log="$outdir/$name.log"
      echo "[check] $name"
      set +e
      (cd "$root" && "$@") > "$log" 2>&1
      status="$?"
      set -u
      echo "$status" > "$outdir/$name.status"
      if [ "$status" -eq 0 ]; then
        echo "  ok"
      else
        echo "  failed: $status"
      fi
      return 0
    }

    if [ -f "$root/flake.nix" ]; then
      run_check nix-flake-check ${pkgs.nix}/bin/nix flake check --no-build --show-trace "path:$root"
    fi

    if command -v hm-check >/dev/null 2>&1; then
      run_check hm-check ${pkgs.coreutils}/bin/env WHOCARES_FLAKE="$root" hm-check
    fi

    if command -v nix-audit >/dev/null 2>&1; then
      run_check nix-audit nix-audit "$root"
    fi

    {
      echo "# Nix/Home Manager Fixpack"
      echo
      echo "I need help debugging this WHOcares!/Nix/Home Manager setup. Use the context and logs below to identify the root cause and give exact commands or a patch. Keep changes reversible and explain any risky step."
      echo
      echo "Root: $root"
      echo "Generated: $(${pkgs.coreutils}/bin/date -Is)"
      echo
      for s in "$outdir"/*.status; do
        [ -f "$s" ] || continue
        name="$(${pkgs.coreutils}/bin/basename "$s" .status)"
        echo "- $name: exit $(${pkgs.coreutils}/bin/cat "$s")"
      done
      echo
      echo "## Context"
      ${pkgs.coreutils}/bin/cat "$outdir/context.md" 2>/dev/null || true
      for log in "$outdir"/*.log; do
        [ -f "$log" ] || continue
        name="$(${pkgs.coreutils}/bin/basename "$log")"
        echo
        echo "## Log: $name"
        echo '```text'
        ${pkgs.coreutils}/bin/cat "$log" | redact_stream
        echo '```'
      done
    } > "$outdir/ask-llm.md"

    copy_file "$outdir/ask-llm.md" >/dev/null 2>&1 || true
    if [ -n "$provider" ]; then
      open_provider "$provider" || true
    fi

    echo
    echo "[saved] $outdir"
    echo "[prompt copied] $outdir/ask-llm.md"
  '';

  hmDoctor = pkgs.writeShellScriptBin "hm-doctor" ''
    exec nix-fixpack "$@"
  '';

  llmReview = pkgs.writeShellScriptBin "llm-review" ''
    set -uo pipefail
    ${commonShell}

    provider=""
    target="$PWD"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --open)
          shift
          provider="''${1:?--open requires a provider}"
          ;;
        --target|-C)
          shift
          target="''${1:?--target requires a directory}"
          ;;
        -h|--help)
          echo "Usage: llm-review [--target DIR] [--open PROVIDER]"
          exit 0
          ;;
        *)
          if [ -d "$1" ]; then target="$1"; else echo "Unknown arg: $1" >&2; exit 2; fi
          ;;
      esac
      shift
    done

    root="$(${pkgs.bash}/bin/bash -lc 'cd "$1" && git rev-parse --show-toplevel 2>/dev/null || pwd' _ "$target")"
    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    outdir="''${WHOCARES_LLM_STATE:-${stateDir}}/reviews/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir"

    ctx --target "$root" --brief --output "$outdir/context.md" >/dev/null || true
    (
      cd "$root" &&
      {
        echo "# Git Review Request"
        echo
        echo "Review my current changes. Find bugs, bad Nix patterns, unsafe shell logic, missing imports/options, and better automation UX. Return exact patch suggestions."
        echo
        echo "## Git status"
        echo '```text'
        git status --short --branch 2>&1 | redact_stream
        echo '```'
        echo
        echo "## Diff stat"
        echo '```text'
        git diff --stat 2>&1 | redact_stream
        git diff --staged --stat 2>&1 | redact_stream
        echo '```'
        echo
        echo "## Unstaged diff"
        echo '```diff'
        git diff 2>&1 | redact_stream
        echo '```'
        echo
        echo "## Staged diff"
        echo '```diff'
        git diff --staged 2>&1 | redact_stream
        echo '```'
        echo
        echo "## Context"
        ${pkgs.coreutils}/bin/cat "$outdir/context.md" 2>/dev/null || true
      }
    ) > "$outdir/ask-llm.md"

    copy_file "$outdir/ask-llm.md" >/dev/null 2>&1 || true
    if [ -n "$provider" ]; then
      open_provider "$provider" || true
    fi
    echo "[prompt copied] $outdir/ask-llm.md"
  '';

  llmPatch = pkgs.writeShellScriptBin "llm-patch" ''
    set -euo pipefail
    ${commonShell}

    invocation_dir="$PWD"
    allow_dirty=0
    use_clipboard=0
    run_checks=1
    patch_arg=""

    usage() {
      cat <<'USAGE'
    Usage: llm-patch [PATCH_FILE]
           llm-patch --clipboard
           cat fix.patch | llm-patch

    Safely applies an AI-generated unified diff:
      1. requires a git repo
      2. refuses dirty trees unless --allow-dirty is passed
      3. creates branch llm/patch-<timestamp>
      4. runs git apply --check before applying
      5. runs flake/HM checks when available
    USAGE
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --allow-dirty) allow_dirty=1 ;;
        --clipboard) use_clipboard=1 ;;
        --no-checks) run_checks=0 ;;
        -h|--help) usage; exit 0 ;;
        *) patch_arg="$1" ;;
      esac
      shift
    done

    root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null)" || {
      echo "llm-patch must run inside a git repository" >&2
      exit 2
    }

    if [ -n "$patch_arg" ] && [ "''${patch_arg#/}" = "$patch_arg" ]; then
      patch_arg="$invocation_dir/$patch_arg"
    fi

    cd "$root" || exit 2

    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    outdir="''${WHOCARES_LLM_STATE:-${stateDir}}/patches/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$outdir"
    patchfile="$outdir/input.patch"

    if [ -n "$patch_arg" ]; then
      [ -f "$patch_arg" ] || {
        echo "Patch file not found: $patch_arg" >&2
        exit 2
      }
      ${pkgs.coreutils}/bin/cp -- "$patch_arg" "$patchfile"
    elif [ "$use_clipboard" -eq 1 ]; then
      if command -v wl-paste >/dev/null 2>&1; then
        wl-paste > "$patchfile"
      elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard -o > "$patchfile"
      else
        echo "No clipboard paste tool found." >&2
        exit 2
      fi
    elif [ ! -t 0 ]; then
      ${pkgs.coreutils}/bin/cat > "$patchfile"
    else
      usage >&2
      exit 2
    fi

    if ! ${pkgs.gnugrep}/bin/grep -qE '^(diff --git|--- |\+\+\+ )' "$patchfile"; then
      echo "Patch does not look like a unified diff: $patchfile" >&2
      exit 2
    fi

    if [ "$allow_dirty" -ne 1 ] && [ -n "$(${pkgs.git}/bin/git status --porcelain)" ]; then
      echo "Working tree is dirty. Commit/stash first, or use --allow-dirty." >&2
      ${pkgs.git}/bin/git status --short
      exit 3
    fi

    echo "[patch] checking"
    if ! ${pkgs.git}/bin/git apply --check "$patchfile" > "$outdir/git-apply-check.log" 2>&1; then
      echo "Patch failed git apply --check. See: $outdir/git-apply-check.log" >&2
      exit 4
    fi

    branch="llm/patch-$stamp"
    ${pkgs.git}/bin/git switch -c "$branch"

    echo "[patch] applying on branch $branch"
    ${pkgs.git}/bin/git apply "$patchfile"
    ${pkgs.git}/bin/git status --short > "$outdir/status-after-apply.txt"

    if [ "$run_checks" -eq 1 ]; then
      if [ -f flake.nix ]; then
        echo "[check] nix flake check --no-build --show-trace"
        set +e
        ${pkgs.nix}/bin/nix flake check --no-build --show-trace "path:$root" > "$outdir/nix-flake-check.log" 2>&1
        status="$?"
        set -e
        echo "$status" > "$outdir/nix-flake-check.status"
      fi
      if command -v hm-check >/dev/null 2>&1; then
        echo "[check] hm-check"
        set +e
        ${pkgs.coreutils}/bin/env WHOCARES_FLAKE="$root" hm-check > "$outdir/hm-check.log" 2>&1
        status="$?"
        set -e
        echo "$status" > "$outdir/hm-check.status"
      fi
    fi

    {
      echo "# AI Patch Apply Report"
      echo
      echo "Branch: $branch"
      echo "Root: $root"
      echo "Patch: $patchfile"
      echo
      echo "## Git status"
      echo '```text'
      ${pkgs.coreutils}/bin/cat "$outdir/status-after-apply.txt"
      echo '```'
      for s in "$outdir"/*.status; do
        [ -f "$s" ] || continue
        name="$(${pkgs.coreutils}/bin/basename "$s" .status)"
        echo "- $name: exit $(${pkgs.coreutils}/bin/cat "$s")"
      done
    } > "$outdir/report.md"

    echo
    echo "[done] patch applied on branch $branch"
    echo "[saved] $outdir"
    echo "Next: inspect with git diff, then commit or git switch - && git branch -D $branch"
  '';

  whycareHelp = pkgs.writeShellScriptBin "whycare-help" ''
    set -euo pipefail
    db="''${WHOCARES_LLM_COMMANDS:-${registryPath}}"
    query="''${1:-}"

    if [ ! -f "$db" ]; then
      echo "Command registry missing: $db" >&2
      exit 1
    fi

    if [ -z "$query" ]; then
      echo "WHOcares! command skills"
      echo "Usage: why <command-or-search-term>"
      echo
      ${pkgs.gawk}/bin/awk -F '\t' 'NR>1 { printf "  %-14s %-16s %s\n", $1, $2, $3 }' "$db"
      exit 0
    fi

    ${pkgs.gawk}/bin/awk -F '\t' -v q="$query" '
      BEGIN { IGNORECASE=1; found=0 }
      NR == 1 { next }
      $1 == q || $2 ~ q || $3 ~ q || $4 ~ q {
        found=1
        printf "Command:  %s\nCategory: %s\nPurpose:  %s\nExample:  %s\n\n", $1, $2, $3, $4
      }
      END { if (!found) exit 1 }
    ' "$db" || {
      echo "No WHOcares command matched: $query" >&2
      echo "Try: why llm   or   why nix" >&2
      exit 1
    }
  '';
in {
  options.whycare.llmOrchestrator = {
    enable = mkEnableOption "WHOcares LLM orchestration and self-documenting automation commands";

    browser = mkOption {
      type = types.str;
      default = "firefox";
      description = "Browser command used by llm-open, llm-chatgpt, and llm-gemini. Falls back to xdg-open.";
    };

    maxFileBytes = mkOption {
      type = types.ints.positive;
      default = 50000;
      description = "Maximum bytes of each selected file included in ctx bundles.";
    };

    maxFilesBrief = mkOption {
      type = types.ints.positive;
      default = 35;
      description = "Maximum files included by ctx --brief.";
    };

    maxFilesFull = mkOption {
      type = types.ints.positive;
      default = 90;
      description = "Maximum files included by ctx --full.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.maxFilesFull >= cfg.maxFilesBrief;
        message = "whycare.llmOrchestrator.maxFilesFull must be at least maxFilesBrief";
      }
    ];

    home.packages = [
      ctx
      llmCopy
      llmOpen
      llmChatgpt
      llmGemini
      runlog
      nixFixpack
      hmDoctor
      llmReview
      llmPatch
      whycareHelp

      pkgs.coreutils
      pkgs.findutils
      pkgs.gnused
      pkgs.gawk
      pkgs.gnugrep
      pkgs.git
      pkgs.jq
      pkgs.ripgrep
      pkgs.fd
      pkgs.bat
      pkgs.fzf
      pkgs.wl-clipboard
      pkgs.xclip
      pkgs.xdg-utils
      pkgs.util-linux
      pkgs.diffutils
      pkgs.iproute2
    ];

    home.sessionVariables = {
      WHOCARES_LLM_STATE = stateDir;
      WHOCARES_LLM_COMMANDS = registryPath;
    };

    xdg.dataFile."whocares/llm-orchestrator/commands.tsv".text = commandRegistry;

    xdg.dataFile."whocares/llm-orchestrator/README.md".text = ''
      # WHOcares! LLM Orchestrator

      This module turns the machine into a context-capturing, browser-handoff,
      patch-testing workstation for someone orchestrating LLMs without needing to
      manually know every Nix, shell, or git detail.

      ## Core commands

      | Command | Purpose |
      |---|---|
      | `why [term]` | Explain installed WHOcares commands by command/category/purpose. |
      | `ctx` | Capture repo/system/Nix/git context as Markdown. |
      | `ctx --copy --open chatgpt` | Copy context to the clipboard and open ChatGPT. |
      | `llm-copy` | Copy stdin/files/directories as a pasteable LLM prompt. |
      | `llm-open gemini FILE` | Copy a file/context prompt and open Gemini. |
      | `runlog COMMAND ...` | Run a command, save transcript, copy an LLM debug prompt. |
      | `nix-fixpack` / `hm-doctor` | Build a full Nix/Home Manager diagnostic bundle. |
      | `llm-review` | Package current git diff for review. |
      | `llm-patch` / `aipatch` | Apply an AI-generated patch on a new git branch and run checks. |

      ## Good flows

      ```sh
      # Ask a cloud LLM to help with the current repo
      ctx --copy --open chatgpt

      # Run a failing command and immediately get a pasteable prompt
      runlog hm-check

      # Make one big Nix/Home Manager debug bundle
      nix-fixpack --open gemini

      # Review uncommitted changes before committing
      llm-review --open chatgpt

      # Apply a patch from clipboard safely
      llm-patch --clipboard
      ```

      The module redacts common token/key/password patterns, but context capture
      is still explicit and user-triggered. Read sensitive bundles before pasting
      them into outside services.
    '';

    programs.zsh.shellAliases = {
      why = "whycare-help";
      skills = "whycare-help";
      ctxc = "ctx --copy";
      ctxf = "ctx --save";
      gpt = "llm-chatgpt";
      gem = "llm-gemini";
      fixpack = "nix-fixpack";
      doctor = "hm-doctor";
      aipatch = "llm-patch";
      review = "llm-review";
      rr = "runlog";
    };

    programs.zsh.initContent = mkAfter ''
      # LLM orchestration helpers that need access to interactive Zsh history.
      lastlog() {
        emulate -L zsh
        local cmd
        cmd="$(fc -ln -2 -2 2>/dev/null | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//')"
        [[ -n "$cmd" ]] || { echo "No previous command found" >&2; return 1; }
        print -r -- "[lastlog] $cmd"
        runlog zsh -lc "$cmd"
      }

      lastask() {
        emulate -L zsh
        local cmd
        cmd="$(fc -ln -2 -2 2>/dev/null | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//')"
        [[ -n "$cmd" ]] || { echo "No previous command found" >&2; return 1; }
        {
          print -r -- "# Explain this shell command"
          print -r -- ""
          print -r -- "Explain what this command does, why it might fail, and safer alternatives."
          print -r -- ""
          print -r -- '```sh'
          print -r -- "$cmd"
          print -r -- '```'
          print -r -- ""
          ctx --brief
        } | llm-open chatgpt
      }
    '';

    programs.nushell.extraConfig = ''
      alias why = whycare-help
      alias skills = whycare-help
      alias ctxc = ctx --copy
      alias ctxf = ctx --save
      alias gpt = llm-chatgpt
      alias gem = llm-gemini
      alias fixpack = nix-fixpack
      alias doctor = hm-doctor
      alias aipatch = llm-patch
      alias review = llm-review
      alias rr = runlog
    '';
  };
}
