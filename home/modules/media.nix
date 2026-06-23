# MPV, Celluloid, and shell helpers for local and network media.
{
  config,
  pkgs,
  ...
}: let
  mediaQueue = pkgs.writeShellApplication {
    name = "media-queue";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.mpv
      pkgs.socat
    ];
    text = ''
      if [[ $# -eq 0 ]]; then
        echo "Usage: media-queue <file-or-url> [...]" >&2
        exit 2
      fi

      runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
      socket="$runtime_dir/whocares-mpv-''${UID}.sock"

      if [[ ! -S "$socket" ]]; then
        rm -f -- "$socket"
        mpv \
          --idle=yes \
          --force-window=yes \
          --input-ipc-server="$socket" \
          --no-terminal \
          >/dev/null 2>&1 &

        for _ in $(seq 1 50); do
          [[ -S "$socket" ]] && break
          sleep 0.1
        done
      fi

      [[ -S "$socket" ]] || {
        echo "media-queue: mpv IPC socket did not start" >&2
        exit 1
      }

      for item in "$@"; do
        case "$item" in
          *://*) media="$item" ;;
          *) media="$(realpath -m -- "$item")" ;;
        esac

        jq -nc --arg media "$media" \
          '{command:["loadfile",$media,"append-play"]}' \
          | socat - "UNIX-CONNECT:$socket"
      done
    '';
  };

  mediaClear = pkgs.writeShellApplication {
    name = "media-clear";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.socat
    ];
    text = ''
      socket="''${XDG_RUNTIME_DIR:-/tmp}/whocares-mpv-''${UID}.sock"
      [[ -S "$socket" ]] || {
        echo "media-clear: no WHOcares mpv session" >&2
        exit 1
      }
      jq -nc '{command:["playlist-clear"]}' | socat - "UNIX-CONNECT:$socket"
    '';
  };

  mediaStatus = pkgs.writeShellApplication {
    name = "media-status";
    runtimeInputs = [pkgs.playerctl];
    text = ''
      exec playerctl --player=mpv metadata \
        --format '{{status}}  {{artist}} {{title}}  {{position}}'
    '';
  };
in {
  programs.mpv = {
    enable = true;
    package = pkgs.mpv;
    defaultProfiles = ["gpu-hq"];
    config = {
      profile = "high-quality";
      vo = "gpu-next";
      hwdec = "auto-safe";
      gpu-context = "wayland";
      keep-open = true;
      save-position-on-quit = true;
      watch-later-options = "start,vid,aid,sid";
      ytdl-format = "bestvideo+bestaudio/best";
      cache = true;
      demuxer-max-bytes = "512MiB";
      demuxer-max-back-bytes = "128MiB";
      screenshot-format = "png";
      screenshot-directory = "${config.xdg.userDirs.pictures}/mpv";
      osd-bar = false;
      border = false;
    };
    profiles.gpu-hq = {
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      dscale = "mitchell";
      deband = true;
    };
    scripts = with pkgs.mpvScripts; [
      autoload
      memo
      mpris
      quality-menu
      sponsorblock
      thumbfast
      uosc
    ];
    scriptOpts = {
      uosc = {
        timeline_size = 40;
        timeline_persistency = "paused";
        controls = "menu,gap,subtitles,gap,audio,gap,playlist,chapters";
      };
      sponsorblock = {
        categories = "sponsor;selfpromo;interaction;intro;outro;preview";
      };
    };
    bindings = {
      q = "quit-watch-later";
      Q = "quit";
      "Ctrl+r" = "script-binding quality_menu/video_formats_toggle";
      "Ctrl+a" = "script-binding quality_menu/audio_formats_toggle";
      "Alt+LEFT" = "playlist-prev";
      "Alt+RIGHT" = "playlist-next";
      "WHEEL_UP" = "add volume 2";
      "WHEEL_DOWN" = "add volume -2";
    };
  };

  home.packages = with pkgs; [
    celluloid
    ffmpeg-full
    mediainfo
    playerctl
    yt-dlp
    mediaQueue
    mediaClear
    mediaStatus
  ];

  home.sessionVariables.MPV_HOME = "${config.xdg.configHome}/mpv";

  programs.zsh.shellAliases = {
    play = "mpv --save-position-on-quit";
    audio = "mpv --no-video";
    shuffle = "mpv --shuffle --loop-playlist=inf";
    queue = "media-queue";
    now = "media-status";
  };

  programs.nushell.extraConfig = ''
    alias play = mpv --save-position-on-quit
    alias audio = mpv --no-video
    alias shuffle = mpv --shuffle --loop-playlist=inf
    alias queue = media-queue
    alias now = media-status
  '';

  xdg.mimeApps.defaultApplications = {
    "audio/aac" = "io.github.celluloid_player.Celluloid.desktop";
    "audio/flac" = "io.github.celluloid_player.Celluloid.desktop";
    "audio/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
    "audio/ogg" = "io.github.celluloid_player.Celluloid.desktop";
    "audio/x-wav" = "io.github.celluloid_player.Celluloid.desktop";
    "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
    "video/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
    "video/ogg" = "io.github.celluloid_player.Celluloid.desktop";
    "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
    "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
    "x-scheme-handler/magnet" = "io.github.celluloid_player.Celluloid.desktop";
  };
}
